# virtualsprite_arena
Virtual sprite benchmark for pico8

This project contains a pico8 cartridge with a benchmark of virtual sprite rendering.

It contains 4 banks of PX9 compressed spritesheet that are unpacked when the cartridge boot.
Then a bunch of benchmark are launched to test different cache strategies with differents configurations.

[Link to the official BBS ](https://www.lexaloffle.com/bbs/?tid=47621)

- benchmark.p8 contains the compress gfx data, the benchmark launcher, and the differents virtual sprite algos
- compress_pack.p8 is a utility cartridge that pack gfx from pack1 to pack4 files
- packX.p8 contain a fullsize uncompressed sprite sheet

