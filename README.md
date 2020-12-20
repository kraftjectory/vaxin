# Vaxin

A validator combinator library for Elixir

## Installation

```elixir
def deps() do
  [
    {:vaxin, "~> 0.1.0"}
  ]
end
```

Full documentation can be found on [HexDocs][hexdocs-url]

## Usage

Vaxin at its core is a data validator combinator library. It tries to solve
the problem of validating the shape and content of some data (most useful
when such data come from an external source) and of conforming those data
to arbitrary formats.

Vaxin is based on the concept of validators: a validator is something that
knows how to validate a term and transform it to something else if necessary.
A good example of a validator could be something that validates that a term is
a string representation of an integer and that converts such string to the
represented integer.

### Validators

A validator is a function that takes one argument and returns either:
* `{:ok, transformed}` - indicating the validation has succeeded (the input
    term is considered valid) and `transformed` is the conformed value for the
    input term.

  * `{:error, reason}` - indicating means the validation has failed (the input
    term is invalid). `reason` can be a string representing the error message
    or a `Vaxin.Error`. Note that `validate/2` will eventually wrap the error
    message into a `Vaxin.Error`.

  * `true` - indicating the validation has succeeded. It has the same effect
    as `{:ok, transformed}`, but it can be used when the transformed value
    is the same as the input value. This is useful for "predicate" validators
    (functions that take one argument and return a boolean).

  * `false` - it means validation failed. It is the same as `{:error, reason}`,
    except the reason only mentions that a "predicate failed".

Returning a boolean value is supported so that existing predicate functions
can be used as validators without modification. Examples of such functions are
type guards (`is_binary/1` or `is_list/1`), functions like `String.valid?/1`,
and many others.

The concept of validators is very powerful as they can be easily combined: for
example, the `Vaxin.all_of/1` function takes a list of validators and returns
a validator that passes if all of the given validators pass. Vaxin provides both
"basic" validators as well as validator combinators.

### Built-in validators

On top of powerful built-in Elixir predicate functions, Vaxin also provides
a few built-in validators. You might notice that they are very similar to
the `Ecto.Changeset` API. The intention is to enable developers who are familiar
with Ecto to be immediately productive with Vaxin. However, there is a few
fundamental difference between two libraries:

* Vaxin built-in validators take in options and return a **validator** which
can be used with `Vaxin.validate/2` later.

* Vaxin does **not** have the concept of "empty" values. `nil` or empty strings
are treated the same way as other Elixir data.

Consider the following example: `nil` will be validated with Vaxin while Ecto
would skip it.

```elixir
iex> import Vaxin
iex> validator = validate_number(greater_than: 0)
iex> {:error, error} = validate(validator, nil)
iex> Exception.message(error)
"must be a number"
```

## Examples

Let's say S.H.I.E.L.D are looking for a replacement for Captain America and receive
thousands of applications, they could use Vaxin to build a profile validator.

```elixir
iex> import Vaxin
iex>
iex> age_validator =
...>   validate_number(
...>     &is_integer/1,
...>     greater_than: 18,
...>     message: "is too young to be a superhero"
...>   )
iex>
iex> superpower_validator =
...>   validate_inclusion(
...>     &is_binary/1,
...>     ["fly", "strength", "i-can-do-this-all-day"],
...>     message: "is unfortunately not the super-power we are looking for"
...>   )
iex> superhero_validator =
...>   (&is_map/1)
...>   |> validate_key("age", :required, age_validator)
...>   |> validate_key("superpower", :required, superpower_validator)
iex>
iex> peter_parker = %{"age" => 16, "superpower" => "speed"}
iex> {:error, error} = Vaxin.validate(superhero_validator, peter_parker)
iex> Exception.message(error)
~s("age" is too young to be a superhero)
iex>
iex> falcon = %{"age" => 40, "superpower" => "fly"}
iex> Vaxin.validate(superhero_validator, falcon)
{:ok, %{"age" => 40, "superpower" => "fly"}}
```

## Credits

Vaxin was heavily inspired by [Saul][saul] and [Ecto.Changeset][ecto].

## License

ISC


[hexdocs-url]: https://hexdocs.pm/vaxin
[saul]: https://github.com/whatyouhide/saul
[ecto]: https://github.com/elixir-ecto/ecto
