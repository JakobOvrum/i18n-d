Internationalized Hello World
============================================
This example program aims to write "hello, world" in your system's language
to stdout, and acts as a simple example of how to use `i18n.text` to translate
programs. Simply run the program with `dub run` and it will display "hello,
world" according to your system's language preferences, falling back to English
if no translation is provided. If your preferred language is missing, a pull
request adding it would be appreciated!

Structure
============================================

 * `source/hello.d`: the program source code, showing how to reference the
"hello, world" string.
 * `views/i18n`: directory containing string catalogs. `views` is automatically
added as a string import path by dub. Different locations can be added with the
`importPath[s]` directive.

