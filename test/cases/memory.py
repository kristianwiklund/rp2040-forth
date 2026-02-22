TESTS = [
    {
        "id": "8.1",
        "section": "Memory",
        "setup": ["CREATE MYVAR", "42 MYVAR !"],
        "input": "MYVAR @ .",
        "expect": "42 ",
        "match": "exact",
        "note": "Variable create/store/fetch",
    },
    {
        "id": "8.2",
        "section": "Memory",
        "setup": [],
        "input": "HERE .",
        "expect": None,
        "match": "any",
        "note": "HERE returns non-zero heap pointer (non-deterministic)",
    },
    {
        "id": "8.3",
        "section": "Memory",
        "setup": ["CREATE MYBYTE", "65 MYBYTE C!"],
        "input": "MYBYTE C@ .",
        "expect": "65 ",
        "match": "exact",
        "note": "Byte store/fetch",
    },
]
