compile:
    gcc -g -nostdlib -static -Wl,--build-id=none -o words words.S

run: compile
    ./words

time: compile
    time just run
