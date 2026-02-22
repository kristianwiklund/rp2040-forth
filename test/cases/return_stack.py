TESTS = [
    {
        "id": "9.1",
        "section": "Return Stack",
        "setup": [": TESTRS 10 >R 20 . R> . ;"],
        "input": "TESTRS",
        "expect": "20 10 ",
        "match": "exact",
        "note": ">R hides 10; . prints 20; R> retrieves 10",
    },
]
