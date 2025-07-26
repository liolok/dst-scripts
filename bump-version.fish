#!/usr/bin/env fish

set steam_lib $HOME/steam-library
set dst_dir "$steam_lib/common/Don't Starve Together"

set upstream_version (string trim (cat $dst_dir/version.txt))
printf 'Version of Steam installation: %d\n' $upstream_version

set local_version (string trim (cat version.txt))
printf 'Version of current repository: %d\n' $local_version

if test $local_version -ge $upstream_version # local >= upstream
    echo 'Current version is already up to date.'
    exit
end

for file in ./scripts/*
    chmod --recursive --quiet u+w $file # restore write permission
    rm --recursive $file # clear all
end

unzip -q $dst_dir/data/databundles/scripts.zip # extract new version

for file in ./scripts/*
    chmod --recursive --quiet a-w $file # remove write permission
end

echo 'Version bumped.'
cp $dst_dir/version.txt ./
