# IBM 5100 — M-003 Level 17 Reference File
Asset: IBM-5100-SIM-01
Location: M-003 / Level 17 Maintenance Workshop
Record type: historical technical reference + browser educational simulator

## Verified historical overview
- IBM announced the IBM 5100 Portable Computer in September 1975.
- It integrated a keyboard, a small monochrome CRT display, magnetic tape cartridge storage, and built-in BASIC and/or APL language interpreters depending on model.
- Main storage configurations included 16 KB, 32 KB, 48 KB and 64 KB.
- Contemporary technical reports describe a display capacity of 1,024 characters and a tape cartridge capacity around 204 KB.
- The machine was a transportable, self-contained system weighing roughly 50–55 pounds, not a modern lightweight laptop.
- The architecture used IBM's proprietary PALM controller/microcode approach; avoid assuming it was a conventional modern x86 CPU.

## M-003 implementation
The browser page is an educational UI simulation, not original IBM firmware or a cycle-accurate hardware emulator.
Functions: CRT-style terminal, limited BASIC subset (PRINT, LET, REM, END and arithmetic), APL scalar-expression teaching subset (← assignment, variables, + − × ÷), sample programs, calculator, browser-local simulated tape cartridges, owner/security gate, and a cloud program archive.
The APL subset is educational only and is not a full APL interpreter or original IBM APL implementation.
Tape storage uses browser localStorage. Cloud program source is stored in Supabase table public.m003_ibm5100_programs, restricted by RLS to the signed-in owner of parcel M-003 and scoped to floor 17.

## John Titor context
John Titor was an online persona who claimed to be a time traveler. IBM 5100's real technical history does not substantiate those claims. Any claim that the 5100 had secret time-travel capabilities is unsupported.

## References
- IBM 5100 BASIC Reference Manual, July 1977: https://bitsavers.trailing-edge.com/pdf/ibm/5100/SA21-9217-3_IBM_5100_BASIC_Reference_Manual_Jul1977.pdf
- Columbia University Computing History: https://www1.columbia.edu/cu/computinghistory/5100.html
- Computer History Museum: https://www.computerhistory.org/revolution/mobile-computing/18/316/1686
- IBM 5100 Maintenance Information Manual: https://computermuseum.informatik.uni-stuttgart.de/ftp/ibm/ibm5100/SY31-0405-2_IBM5100_MaintenceInformationManual_Oct1976.pdf
