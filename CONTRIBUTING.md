# Contributing to FreeSpec

FreeSpec is a free software distributed under the terms of the
GPLv3. It remains under active development, and we welcome external
contributions.

## Getting Involved

The autoritative repository of FreeSpec is hosted on
[GitHub](https://github.com/ANSSI-FR/FreeSpec). If you have a
question, if you have found a bug or if there is a feature you would
want to see added to FreeSpec (and even implement it yourself), feel
free to open an issue. It is always recommended to discuss a change
before sending patches that implement it.

## Coding Style

### Line Width

The 80th column is a soft limit for line width: we can exceed it to
conclude an incomplete “term”, but we cannot start a new one. The
100th column is a hard limit: we should never exceed it.

So, for instance, the following line of code meets our requirement.

```coq
(* good                                                                         |                   | *)
  my_very_long_function_name (another_function x) (yet_another_function_even_longer y)
(*                                                                              |                   | *)
```

It exceeds the 80th column, but only to conclute the term
`yet_another_function_even_longer y`. On the contrary, the following
line does not meet our requirements, since we introduce a new term
(here, simply `z`) after the one we were defining while exceeding the
80th column.

```coq
(* good                                                                         |                   | *)
  my_very_long_function_name (another_function x) (yet_another_function_even_longer y) z
(*                                                                              |                   | *)
```

### Function Definitions and Newlines

When we can, we shall not introduce newlines to function declarations.

```coq
(* bad *)
Definition my_function (x : nat)
                       (y : Z)
  : nat :=
  (* ... *)

(* good *)
Definition my_function (x : nat) (y : Z) : nat :=
  (* ... *)
```

If a function declaration exceeds 100 characters, then a newline is
required and several rules apply:

1. As far as possible, arguments of the same line should have
   something in common. For instance, one can reserve a line to
   introduce a set of arguments, and another to explicit constraints
   (living in `Prop`) about these arguments.
2. A line of function arguments shall start with four spaces.
3. The return type shall has its own line of the form `: <type> :=`
   with two leading spaces.

```coq
(* bad *)
Definition my_very_long_function (x y z : complicated_type) (my_pred : a_predicate x y) (another_pred : property z) : nat :=
  (* ... *)
```

As rule 1. is subjective, there are several acceptable way to format a
function declaration.

```coq
(* good *)
Definition my_very_long_function (x y z : complicated_type)
    (my_pred : a_predicate x y)
    (another_pred : property z)
  : nat :=
  (* ... *)
```

### Implicit Arguments

We omit the types of implicit arguments.

```coq
(* bad *)
Definition identity {a : Type} (x : a) : a := x.

(* good *)
Definition identity {a} (x : a) : a := x.
```

When Coq provides us the means to declare a function argument as
implicit while defining the function itself (*e.g.*, with the
`Definition` keyword for instance), we prefer this approach.

```coq
(* bad *)
Definition identity a (x : a) : a := x.
Arguments identity [a] (x).

(* good *)
Definition identity {a} (x : a) : a := x.
```
