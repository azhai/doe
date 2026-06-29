use a './test_mods/stmt_error.do'

--cytest: error
--CompileError: Top level statement is not allowed from imported module.
--
--@AbsPath(src/test/modules/test_mods/stmt_error.do):1:1:
--print(123)
--^~~~~~~~~~
--