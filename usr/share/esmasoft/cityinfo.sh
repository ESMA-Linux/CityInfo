#!/bin/bash

# Зависимости
# - bash
# - innoextract
# - wine
# - unzip
# - wget
# - winetricks (скачивается сам)

# Winetricks
# ie7      : устраняет краш, позволяет запуститься
# riched20 : добавляет отображение текста в "советах дня" 

#
# Настройки
#
export CI_VERSION=12

export CI_DIR_SCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export CI_DIR_ROOT="$HOME/.esmasoft/cityinfo"
export CI_DIR_CACHE="$CI_DIR_ROOT/cache"
export CI_DIR_WINEPRFIX="$CI_DIR_ROOT/wine"
export CI_DIR_TEMP="$CI_DIR_ROOT/temp"

export CI_FILE_VERSION="$CI_DIR_ROOT/VERSION"

export CITYINFO_URL="http://hpc.by/wp-content/uploads/files/cityinfo/cityinfo3073.exe"
export CITYINFO_FILENAME="cityinfo3073.exe"
export CITYINFO_CHECKSUM="43299557dda6668dd2934d86dbafc92232e099a4"

export LIBKASNERIK_VERSION="0.0.1"
export LIBKASNERIK_URL="https://github.com/ESMA-Linux/libKasnerik/releases/download/$LIBKASNERIK_VERSION/libKasnerik_$LIBKASNERIK_VERSION.zip"
export LIBKASNERIK_FILENAME="libKasnerik_$LIBKASNERIK_VERSION.zip"

export WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"


#
# Winetricks
#
# Winetricks authors, GPL2
winetricks_parse_wget_progress()
{
    # Parse a percentage, a size, and a time into $1, $2 and $3
    # then use them to create the output line.
    perl -p -e \
       '$| = 1; s/^.* +([0-9]+%) +([0-9,.]+[GMKB]) +([0-9hms,.]+).*$/\1\n# Downloading... \2 (\3)/'
}

winetricks_get_sha1sum()
{
    local _W_file="$1"

    if [ -f "$_W_file" ] || [ -h "$_W_file" ]
    then
        _W_gotsum=`sha1sum < "$_W_file" | sed 's/(stdin)= //;s/ .*//'`
    else
        return
    fi
}

winetricks_wget_progress()
{
	# Usa a subshell so if the user clicks 'Cancel',
	# the --auto-kill kills the subshell, not the current shell
	(
	    wget "$@" 2>&1 |
	    winetricks_parse_wget_progress | \
	    zenity --progress --no-cancel --width 400 --title="$_W_title" --auto-kill --auto-close
	)
	err=$?
	if test $err -gt 128
	then
	    # 129 is 'killed by SIGHUP'
	    # Sadly, --auto-kill only applies to parent process,
	    # which was the subshell, not all the elements of the pipeline...
	    # have to go find and kill the wget.
	    # If we ran wget in the background, we could kill it more directly, perhaps...
	    if pid=`ps augxw | grep ."$_W_file" | grep -v grep | awk '{print $2}'`
	    then
		echo User aborted download, killing wget
		kill $pid
	    fi
	fi
	return $err

}

winetricks_download()
{
	_W_url="$1"
	_W_file="$2"
	_W_title="$3"
	_W_checksum="$4"

	winetricks_get_sha1sum

        if [ "$_W_gotsum"x != "$_W_checksum"x ] || [ "$_W_checksum" = "" ];
        then
		winetricks_wget_progress -O "$_W_file" -nd -c --read-timeout=300 --retry-connrefused "$_W_url"
	fi
}

winetricks_install()
{
	cd "$CI_DIR_TEMP"
	winetricks_download "$WINETRICKS_URL" "./winetricks" "Downloading winetricks"
	chmod +x ./winetricks

	#ie7
	winetricks_download "http://download.microsoft.com/download/3/8/8/38889DC1-848C-4BF2-8335-86C573AD86D9/IE7-WindowsXP-x86-enu.exe" "$HOME/.cache/winetricks/ie7/IE7-WindowsXP-x86-enu.exe" "Downloading IE7" "d39b89c360fbaa9706b5181ae4718100687a5326"
	WINEPREFIX="$CI_DIR_WINEPRFIX" ./winetricks --force --optout --unattended ie7

	#riched20
	winetricks_download "https://web.archive.org/web/20160129053851/http://download.microsoft.com/download/E/6/A/E6A04295-D2A8-40D0-A0C5-241BFECD095E/W2KSP4_EN.EXE" "$HOME/.cache/winetricks/win2ksp4/W2KSP4_EN.EXE" "Downloading Windows 2000 SP4" "fadea6d94a014b039839fecc6e6a11c20afa4fa8"
	WINEPREFIX="$CI_DIR_WINEPRFIX" ./winetricks --force --optout --unattended riched20
}


#
#
#
directories_prepare()
{
	rm -rf "$CI_DIR_WINEPRFIX/"
	rm -rf "$CI_DIR_TEMP/"

	mkdir -p "$CI_DIR_CACHE"
	mkdir -p "$CI_DIR_ROOT"
	mkdir -p "$CI_DIR_TEMP"

	cd "$CI_DIR_ROOT"
}

directories_clean()
{
	rm -rf "$CI_DIR_TEMP/"
}

wine_createPrefix()
{
	WINEPREFIX="$CI_DIR_WINEPRFIX" WINEARCH="win32" WINEDLLOVERRIDES="mscoree,mshtml=" wineboot
}

cityInfo_download()
{
	winetricks_download "$CITYINFO_URL" "$CI_DIR_CACHE/$CITYINFO_FILENAME" "Downloading CityInfo" "$CITYINFO_CHECKSUM"
	cp "$CI_DIR_CACHE/$CITYINFO_FILENAME" "$CI_DIR_TEMP/$CITYINFO_FILENAME"
}

cityInfo_unpackAndCopy()
{
	cd "$CI_DIR_TEMP"
	innoextract ./"$CITYINFO_FILENAME"
        mkdir -p "$CI_DIR_WINEPRFIX/drive_c/Program Files/CityInfo/"
	cp -R "./app/." "$CI_DIR_WINEPRFIX/drive_c/Program Files/CityInfo/"
}

cityInfo_bugfix()
{
	mkdir -p "$CI_DIR_WINEPRFIX/drive_c/users/$USER/Application Data/ESMA/CityInfo/"
	cp "$CI_DIR_SCRIPT/cityinfo_fixes/default.bsf" "$CI_DIR_WINEPRFIX/drive_c/users/$USER/Application Data/ESMA/CityInfo/default.bsf"
}

libKasnerik_download()
{
	cd "$CI_DIR_TEMP"
	winetricks_download "$LIBKASNERIK_URL" "./$LIBKASNERIK_FILENAME" "Downloading LibKasnerik" ""
}

libKasnerik_unpackAndCopy()
{
	cd "$CI_DIR_TEMP"
	unzip -o "./$LIBKASNERIK_FILENAME" -d lib
	cp -R "./lib/." "$CI_DIR_WINEPRFIX/drive_c/Program Files/CityInfo/"
}


installation()
{
	directories_prepare

	wine_createPrefix
	winetricks_install

	cityInfo_download
	cityInfo_unpackAndCopy

	libKasnerik_download
	libKasnerik_unpackAndCopy

	directories_clean

	cityInfo_bugfix

	echo "$CI_VERSION" > "$CI_FILE_VERSION"
}

run()
{
	cd "$CI_DIR_WINEPRFIX/drive_c/Program Files/CityInfo"
	env WINEPREFIX="$CI_DIR_WINEPRFIX" LANG=ru_RU.utf8 wine Kasnerik.exe &
}

main()
{
	if [ -f "$CI_FILE_VERSION" ];
	then
	   export CI_VERSION_INSTALLED=$(cat "$CI_FILE_VERSION")
	else
	   export CI_VERSION_INSTALLED="-1"
	fi

	if [ $CI_VERSION \> $CI_VERSION_INSTALLED ];
	then 
	    installation
	fi

	run
}

main
