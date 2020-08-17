# Bruno Beltran's Dotfiles.

Feel free to use the install.sh script to install them, but you should probably change the relevant entries in `dotfiles/gitconfig` at least.

Also, make sure to do something like the following to see what you're installing

```bash
for file in ls dotfiles; do 
    diff -r "dotfiles/$file" "$HOME/.$file" >>install_dry_run.diff
done
```
