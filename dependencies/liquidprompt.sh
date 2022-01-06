mkdir -p "${HOME}/developer"
if [ ! -d "${HOME}/developer/liquidprompt" ]; then
    git -C ~/developer clone https://github.com/nojhan/liquidprompt.git
fi
