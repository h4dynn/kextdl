#!/bin/bash -e

if [[ "$(uname -s)" == "Darwin" && -z "${ZSH_VERSION}" ]]
then {
  #
  # Switch to zsh since macOS uses an outdated
  # bash version that can't handle new bash syntax
  #
  zsh -e "${0}" ${@}
  exit 0
}
fi

function fatal()
{
  echo -e "kextdl:" "\e[1;31merror (fatal):\e[0m" "$@"
  exit 1
}

function usage()
{
  echo "Usage: kextdl.command [Release/Debug] < kext.list" >&2
  exit 0
}

function parseDlKext()
{
  #
  # kext list is formatted like:
  # Kext/Repo: KextName-{VERSION}-{VARIANT} (MainKext, KextModule1, KextModule2)
  #
  kextRepo="$(cut -d: -f1 <<< ${1})"
  kextName="$(cut -d/ -f2 <<< ${kextRepo})"
  kextZipPattern="$2"

  if (( $# > 2 )) && [[ "${3}" == '('* && "${@}" == *')' ]]
  then {
    shift 2
  	kextFileDls=($(cut -d'(' -f2- <<< ${@} | cut -d')' -f-1 | sed 's/, / /g'))
  }
  else {
    kextFileDls=("${kextName}")
  }
  fi

  export kextRepo kextName kextZipPattern kextFileDls
}

case "${1}" in
  "-h"|"--help")
    usage
    ;;
  *)
    variant="${1}"
    ;;
esac

if [[ -f "./kext.list" ]]
then {
  config="$(realpath -eL ./kext.list)"
}
# Check if stdin is provided instead of a file
elif [[ ! -t 0 ]]
then {
  config="/dev/stdin"
}
else {
  fatal "No configuration provided"
}
fi

mkdir -p Kexts
cd Kexts

if [[ "$(head -n2 < ${config})" == *"# This is an example list, don't actually use it." ]]
then {
  fatal "You can't use the example list, edit it first"
}
fi

while read dlKext
do {
  # Skip comments
  if [[ "${dlKext}" == '#'* || -z "${dlKext}" ]]
  then {
    continue
  }
  fi

  parseDlKext $(xargs <<< ${dlKext})

  #
  # Most kexts will be distributed with a
  # RELEASE/DEBUG variant, usually you will
  # want to go with the Release
  #
  if [[ "${kextZipPattern}" =~ "{VARIANT}" && -z "${variant}" ]]
  then {
    fatal "${kextRepo}: You need to provide a kext variant to download (e.g. Debug/Release)"
  }
  fi

  # Find the latest kext release from the repo
  latestVersion="$(curl https://github.com/${kextRepo}/releases/latest -w '%{redirect_url}' -so /dev/null | cut -d'/' -f8)"

  # Replace version/variant placeholders
  kextZipPattern="$(sed "s/{VERSION}/${latestVersion}/g; s/{VARIANT}/${variant}/g" <<< ${kextZipPattern})"

  echo "Downloading: ${kextRepo} ${latestVersion}" >&2

  downloaded=0
  for zipDlUrl in "https://github.com/${kextRepo}/releases/download/${latestVersion}/${kextZipPattern}.zip" \
                  "https://github.com/${kextRepo}/releases/download/${latestVersion}/${kextZipPattern/${latestVersion}/${latestVersion#v}}.zip"
  do {
    if curl -sfILo /dev/null "${zipDlUrl}"
    then {
      curl -#Lo ".${kextName}.tmp" "${zipDlUrl}"
      downloaded=1
      break
    }
    fi 
  }
  done

  if (( ${downloaded} == 0 ))
  then {
    # Please only use convential version numbers to avoid errors like this
    fatal "${kextRepo}: Failed to find suitable download URL"
  }
  fi

  while read zipFile
  do {
    if [[ "${zipFile}" == "Kexts/"* ]]
    then {
      extractRoot="Kexts/"
      stripComponents='--strip-components=1'
      break
    }
    fi
  }
  done <<< $(bsdtar -t < ".${kextName}.tmp")

  for _kextExtract in "${kextFileDls[@]}"
  do {
    kextExtract+=("${extractRoot}${_kextExtract}.kext")
  }
  done

  eval bsdtar ${stripComponents} \
         -x ${kextExtract[@]} < ".${kextName}.tmp" &&
  rm -f ".${kextName}.tmp"

  # Unset these so they don't interfere with the next
  unset kextFileDls kextExtract _kextExtract extractRoot stripComponents
}
done < "${config}"
