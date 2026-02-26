TESTS = [
    {
        "id": "15.1",
        "section": "Recursion",
        "setup": [": COUNTDOWN DUP . DUP 0 > IF 1 - RECURSE ELSE DROP THEN ;"],
        "input": "3 COUNTDOWN",
        "expect": "3 2 1 0 ",
        "match": "exact",
        "note": "Basic countdown using RECURSE",
    },
    {
        "id": "15.2",
        "section": "Recursion",
        "setup": [": SUMR DUP 0 > IF DUP 1 - RECURSE + ELSE DROP 0 THEN ;"],
        "input": "5 SUMR .",
        "expect": "15 ",
        "match": "exact",
        "note": "Accumulating recursion: sum 1..5",
    },
]
