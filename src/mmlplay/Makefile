PGM=mmlplay.hex

.SUFFIXES:	.asm .hex .bin

all:	$(PGM)

.asm.p:
	asl -L $<

.p.hex:
	p2hex -F Intel $*

.p.bin:
	p2bin -r '0-$$7ff' $*

