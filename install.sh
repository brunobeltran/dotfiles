#!/bin/bash
set -euo pipefail

please_yes () {
    read please yes
    if [[ ( ! -v please ) || "$please" != "please" || \
        ( ! -v yes    ) || "$yes"    != "yes"     ]]; then
        printf "Quitting...no changes were made.\n"
        exit 2
    fi
}


# safely get install.sh's directory (and, by proxy, the repo's directory)
MY_PATH="`dirname \"$BASH_SOURCE\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

if [[ -z "$MY_PATH" ]]; then
    printf "Something went very wrong. Cannot access install.sh's directory.\n"
    exit 1
fi

#echo "$MY_PATH"

printf "About to replace the dotfiles in \n\t\t$HOME\n"
printf "with their equivalents in \n\t\t$MY_PATH/dotfiles\n\n"
printf "Are you sure? (Type 'please yes' to continue): "
please_yes

# now thanks to directory's naming convention, we can drop in symlinks as needed
for file in `ls dotfiles`; do
    linkname="$HOME/.$file"
    target="$MY_PATH/dotfiles/$file"
    if [[ "$file" == "config" ]]; then
        continue
    fi
    if [[ -e "$linkname" || -h "$linkname" ]]; then
        printf "Deleting old dotfile: %s\n" $linkname
        rm -rf "$linkname"
    fi
    printf "Creating symlink: %s -> %s\n" $linkname $target
    ln -s "$target" "$linkname"
done

# config is an entire subdirectory, but we don't want
# to keep it all in the repo, just particular parts,
# so we individually symlink its components
mkdir -p "$HOME/.config"
for file in `ls dotfiles/config`; do
    linkname="$HOME/.config/$file"
    target="$MY_PATH/dotfiles/config/$file"
    if [[ -e "$linkname" || -h "$linkname" ]]; then
        printf "Deleting old .config entry: %s\n" $linkname
        rm -rf "$linkname"
    fi
    printf "Creating symlink: %s -> %s\n" $linkname $target
    ln -s "$target" "$linkname"
done

printf "NOTE: YOU HAVE TO MANUALLY RUN :PlugUpdate in Vim!\n"
printf "\n"
printf "This installer can also install some dependencies (e.g. fonts for\n"
printf "powerline, etc.), would you like to continue?\n"
printf "(Type 'please yes' to continue): "
please_yes

for helper in dependencies; do
    bash "${helper}"
done
