SHELL = /bin/sh
.RECIPEPREFIX = >
.PHONY: clean dump-elf dump-hex

toolchain = arm-none-eabi-
objects = main.o morse.o string.o usb.o
ldscript = program.ld

LD = $(toolchain)ld
AS = $(toolchain)as
CC = $(toolchain)gcc
OBJCOPY = $(toolchain)objcopy
OBJDUMP = $(toolchain)objdump

ASFLAGS = -mcpu=cortex-m0
LDFLAGS = -T $(ldscript)

program.hex : program.elf
> $(OBJCOPY) -O ihex $< $@

program.elf : $(objects)
> $(LD) $(LDFLAGS) -o $@ $^ $(LOADLIBES) $(LDLIBS) 

clean:
> $(RM) -rf *.o *.elf *.hex

dump-elf : program.elf
> $(OBJDUMP) --disassemble-all --all-headers $< | less

# assumes THUMB-only (Cortex-M{whatever})
dump-hex : program.hex
> $(OBJDUMP) --disassemble-all --architecture=arm --disassembler-options=force-thumb --all-headers $< | less

upload : program.hex
> teensy_loader_cli --mcu=TEENSYLC -w $<
