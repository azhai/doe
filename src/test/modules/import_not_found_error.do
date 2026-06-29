use a 'test_mods/missing.do'
b := a

--cytest: error
--CompileError: Import path does not exist: `@AbsPath(src/test/modules/test_mods/missing.do)`
--
--@AbsPath(src/test/modules/import_not_found_error.do):1:7:
--use a 'test_mods/missing.do'
--      ^~~~~~~~~~~~~~~~~~~~~~
--