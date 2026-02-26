TESTS = [
    {
        "id": "14.1", "section": "Storage", "setup": [],
        "input": ': T14A S" /rom/boot.fth" 0 1 OPEN-FILE SWAP DROP 0 = . ; T14A',
        "expect": "1 ", "match": "exact",
        "note": "OPEN-FILE on /rom/boot.fth: ior=0",
    },
    {
        "id": "14.2", "section": "Storage", "setup": [],
        "input": ': T14B S" /rom/nosuch" 0 1 OPEN-FILE SWAP DROP 0 > . ; T14B',
        "expect": "1 ", "match": "exact",
        "note": "OPEN-FILE on missing path: ior nonzero",
    },
    {
        "id": "14.3", "section": "Storage", "setup": [],
        "input": ': T14C S" /rom/boot.fth" 0 1 OPEN-FILE DROP CLOSE-FILE . ; T14C',
        "expect": "0 ", "match": "exact",
        "note": "CLOSE-FILE returns ior=0",
    },
    {
        "id": "14.4", "section": "Storage", "setup": [],
        "input": ': T14D S" /rom/boot.fth" 0 1 OPEN-FILE DROP DUP FILE-SIZE DROP 0 > SWAP CLOSE-FILE DROP . ; T14D',
        "expect": "1 ", "match": "exact",
        "note": "FILE-SIZE on /rom/boot.fth returns positive size",
    },
    {
        "id": "14.5", "section": "Storage", "setup": [],
        "input": ': T14E S" /rom/boot.fth" 0 1 OPEN-FILE DROP DUP HERE 4 ROT READ-FILE DROP SWAP CLOSE-FILE DROP . ; T14E',
        "expect": "4 ", "match": "exact",
        "note": "READ-FILE: request 4 bytes, receive 4",
    },
    {
        "id": "14.6", "section": "Storage", "setup": [],
        "input": ': T14F S" /sd/test.txt" 0 3 OPEN-FILE DROP DUP S" hello" ROT WRITE-FILE DROP CLOSE-FILE DROP S" /sd/test.txt" 0 1 OPEN-FILE DROP DUP HERE 5 ROT READ-FILE DROP SWAP CLOSE-FILE DROP . ; T14F',
        "expect": "5 ", "match": "exact",
        "note": "WRITE-FILE round-trip: write 5 bytes, read back 5",
    },
    {
        "id": "14.7", "section": "Storage", "setup": [],
        "input": ': T14G S" /sd/hi.fth" 0 3 OPEN-FILE DROP DUP S" : HI 72 EMIT ;" ROT WRITE-FILE DROP CLOSE-FILE DROP ; T14G INCLUDE /sd/hi.fth HI',
        "expect": "H", "match": "exact",
        "note": "INCLUDE /sd/hi.fth: write word definition, include, call it",
    },
]
