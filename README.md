# Elm Markup

This is a parser for a succinct markup language allows you to write content and intermix Elm view functions.

This is a solution to an intersection between two problems I've had when considering existing markup languages like Markdown or Asciidoc.

1. I want to embed views created by Elm in my markup and maintain the opportunity to make them interactive.  So, that means not just static html.
2. All of my projects use [Elm UI(formerly Style Elements)]() for handling layout and styling.  I really didn't want to start duplicating style information in CSS just to style some html generated by Markdown or Asciidoc.

In that way, this isn't really a replacement for Markdown or Asciidoc.  It just solves the above problems for my usecases.

Here's a taste:

```
| title
    My fancy cat blog article

Welcome!  Have you hear about /cats/?  They're great.

| image http://placekitten/200/500
    Here's a great picture of my cat, pookie.

How much do I like cats?  A bunch.

```

Which you can parse using `Mark.parse`.

## Principles

Here are the ideas I used to put this library together:

- There is _one_, unambiguous way to construct a given element.

- This library inherits Elm's wariness of infix or symbol based operators.  Instead of having a bunch of symbols and custom syntax rules to denote concepts, we can usually just use real words.

- This library is strict about whitespace.  This is to ensure that a valid markup file will always look aestetically pleasing and approachable.  

- The following should _always_ be easy:

    - Writing markup
    - Reading markup
    - Modifying markup

- In order to do this, the parser needs to be strict about form.  This means that invalid markup will make the parser fail with a nice error message instead of rendering half correct and half wonky.  Think of this as "No runtime errors" but for elm-markup and layout.

- You can add custom blocks and inline elements, which you'll see later. This library is about letting you be expressive in creating content, just with some ground rules about the form it will take.

- On the flip side, we avoid directly embedding any other langauges like `Html`. My current feeling is that a document like this benefits hugely from being **high level** and embedding code can get really messy with weird details.  Fortunately custom blocks are convenient, so I don't forsee this being a problem.



## Basic Text Markup

There are only a very limited set of characters for formatting text.

- `/italic/` _italic_
- `*bold*` **bold**
- `~strike~` ~~strike~~
- `` `code` `` `code`
- `[link text](http://fruits.com)` to create a link.


## Blocks

Everything else is marked using blocks, which begin with `|` and the name of the block.

Here's the beginning of a blog post with a `title` block, which will render as an `h1`, some text, and then an image, some text and a list.

```
| title
    My fancy blog article

Welcome.  Have you hear about /cats/?  They're great.

| image http://placekitten/200/500
    Here's a great picture of my cat, pookie.

How much do I like cats?  Let's make a list.

| list
    - They're great.
    - Seriously, so great.
        - But, lists are pretty good too.

```

Blocks that come with the library are:

- `title` - The title of your document.  This is equivalent to an `h1`.  You should only have one of them.
- `header` - A header in your document, which is equivalent to `h2`.
- `list` - A nested list with an expected indentation of 4 spaces per level. As far as icons:
    - `-` indicates a bullet
    - `->` indicates an arrow
    - `1.` indicates it should be numbered.  Any number can work.

- `image` - Expects two strings, first the src, and then a description of the image.
- `monospace` - Basically a code block without syntax highlighting.

But one of the great powers of this library is in [writing custom blocks](https://package.elm-lang.org/packages/mdgriffith/elm-markup/latest/Mark-Custom) that suite your specific domain or style needs.

You can also restyle any aspect of existing or new blocks using `Mark.parseWith`.


## Reclaiming Typography

We can also reclaim some useful typography that is a bit awkward to handle otherwise.  Normal text will have the following transformations applied.

- `...` is converted to the ellipses unicode character.
- `"` Straight double quotes are [replaced with curly quotes](https://practicaltypography.com/straight-and-curly-quotes.html)
- `'` Single Quotes are replaced with apostrophes.  In the future we might differentiate between curly single quotes and apostrophes.
- `--` is replaced with an en dash `–`
- `---` is replaced with an em dash: `—`
- `<>` - will create a non-breaking space (`&nbsp;`).  This is not for manually increasing space(sequential `<>` tokens will only render as one `&nbsp;`), but to signify that the space between two words shouldn't break when wrapping.  Think of this like glueing two words together.

Escaping the start of any of these characters will cause the transformation to be skipped in that instance.

These transformations also don't apply inside inline `\`code\`` or inside the `monospace` block.

**Note** If you're not familiar with `en-dash` or `em-dash`, I definitely [recommend reading a small bit about it](https://practicaltypography.com/hyphens-and-dashes.html)—they're incredibly useful.



