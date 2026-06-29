use a 'test_mods/a.do'

type Foo:
    field a.Bar  -- Prefix path also allowed.

fn foo(a a.Bar):
    pass

--cytest: pass