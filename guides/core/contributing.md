# Contributing

We welcome contributions to Nerves. Issues, Pull Requests, knowledge sharing and questions
in the various venues are all welcome. When contributing code there are some practicalities
that are helpful to make the process smooth.

Nerves and the various repos related to it have a common coding standard that is intended to
apply everywhere. There are some automated ones and then there is some preferred practices
that are currently manually encouraged.

## Automated checks

The tedious bits are mostly manageable through automated tools. If you want
to avoid fixing CI failures you can run them locally first:

```
mix format --check-formatted
mix deps.unlock --check-unused
mix test
mix credo -a --strict
mix dialyzer
```

Some repos may vary from this. If you notice that they do, please file an issue about it so we
can improve the situation.

## Preferred practices

- Document all public functions.
- Add a typespec to all public functions.
