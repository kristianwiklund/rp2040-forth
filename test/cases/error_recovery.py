TESTS = [
    {
        "id": "11.1",
        "section": "Error Recovery",
        "setup": [],
        "input": "DROP",
        "expect": "stack underflow",
        "match": "error",
        "note": "DROP on empty stack triggers underflow; no ok follows",
    },
    {
        "id": "11.2",
        "section": "Error Recovery",
        "setup": [],
        "input": "5 .",
        "expect": "5 ",
        "match": "exact",
        "note": "After underflow, stack restarted; normal operation resumes",
    },
    {
        "id": "11.3",
        "section": "Error Recovery",
        "setup": [],
        "input": "R>",
        "expect": "return stack underflow",
        "match": "error",
        "note": "R> on empty return stack triggers underflow",
    },
]
