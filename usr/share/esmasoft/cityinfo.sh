#!/bin/bash

# Зависимости
# - bash
# - innoextract
# - wine
# - unzip
# - wget
# - winetricks (скачивается сам)

# Winetricks
# Включенные:
# ie7      : устраняет краш, позволяет запуститься
# riched20 : добавляет отображение текста в "советах дня" 
# Отключенные:
# comctl32 : устраняет одни глитчи, но добавляет другие. Спорный момент

export CI_VERSION=9

export CI_DIR_SCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export CI_DIR_ROOT="$HOME/.esmasoft/cityinfo"
export CI_DIR_CACHE="$CI_DIR_ROOT/cache"
export CI_DIR_WINEPRFIX="$CI_DIR_ROOT/wine"
export CI_DIR_TEMP="$CI_DIR_ROOT/temp"

export CI_FILE_VERSION="$CI_DIR_ROOT/VERSION"

export URL_CITYINFO="http://hpc.by/wp-content/uploads/files/cityinfo/cityinfo3073.exe"
export URL_CITYINFO_FILENAME="cityinfo3073.exe"

export URL_LIBKASNERIK="https://github.com/Mixaill/libKasnerik/releases/download/0.0.1/libKasnerik_0.0.1.zip"
export URL_WINETRICKS="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"

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
	WINEPREFIX="$CI_DIR_WINEPRFIX" WINEARCH="win32" wineboot
}

wine_winetricks()
{
	cd "$CI_DIR_TEMP"
	wget "$URL_WINETRICKS"
	chmod +x ./winetricks
	#WINEPREFIX="$CI_DIR_WINEPRFIX" ./winetricks comctl32 
	WINEPREFIX="$CI_DIR_WINEPRFIX" ./winetricks ie7 
	WINEPREFIX="$CI_DIR_WINEPRFIX" ./winetricks riched20
}

cityInfo_download()
{
	cd "$CI_DIR_TEMP"

	if [ ! -f "$CI_DIR_CACHE/$URL_CITYINFO_FILENAME" ]; then
		wget "$URL_CITYINFO"
		cp "$CI_DIR_TEMP/$URL_CITYINFO_FILENAME" "$CI_DIR_CACHE/$URL_CITYINFO_FILENAME"
	else
		cp "$CI_DIR_CACHE/$URL_CITYINFO_FILENAME" "$CI_DIR_TEMP/$URL_CITYINFO_FILENAME"
	fi
	
}

cityInfo_unpackAndCopy()
{
	cd "$CI_DIR_TEMP"
	innoextract ./cityinfo3073.exe
        mkdir -p "$CI_DIR_WINEPRFIX/drive_c/Program Files/CityInfo/"
	cp -R "./app/." "$CI_DIR_WINEPRFIX/drive_c/Program Files/CityInfo/"
}

cityInfo_bugfix()
{
	mkdir -p "$CI_DIR_WINEPRFIX/drive_c/users/$USER/Application Data/ESMA/CityInfo/"
	cp "$CI_DIR_SCRIPT/cityinfo_fixs/default.bsf" "$CI_DIR_WINEPRFIX/drive_c/users/$USER/Application Data/ESMA/CityInfo/default.bsf"
}

libKasnerik_download()
{
	cd "$CI_DIR_TEMP"
	wget "$URL_LIBKASNERIK"
}

libKasnerik_unpackAndCopy()
{
	cd "$CI_DIR_TEMP"
	unzip -o libKasnerik_0.0.1.zip -d lib
	cp -R "./lib/." "$CI_DIR_WINEPRFIX/drive_c/Program Files/CityInfo/"
}


installation()
{
	directories_prepare

	wine_createPrefix
	wine_winetricks

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
