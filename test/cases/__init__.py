from . import (basic_output, stack, arithmetic, comparison, base,
               control_flow, word_definition, memory, return_stack,
               dictionary, error_recovery, edge_cases, loops, storage,
               recursion)

ALL_TESTS = (basic_output.TESTS + stack.TESTS + arithmetic.TESTS +
             comparison.TESTS + base.TESTS + control_flow.TESTS +
             word_definition.TESTS + memory.TESTS + return_stack.TESTS +
             dictionary.TESTS + error_recovery.TESTS + edge_cases.TESTS +
             loops.TESTS + storage.TESTS + recursion.TESTS)
