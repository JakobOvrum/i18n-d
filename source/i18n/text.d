/**
  * Text translation framework.
  *
  *
  * This library aims to facilitate native language support in applications and
  * libraries written in D. String resources containing natural language _text
  * are read from XML documents, called $(I catalogs), supplied at compile-time.
  * In source code, string resources are referenced with the $(MREF strings)
  * interface. The languages to use are configured automatically at the start
  * of the program based on the running user's environment, before the $(D main)
  * function is entered.
  *
  * $(SECTION2 Catalogs)
  * There are two kinds of catalogs: the singular $(I primary catalog) and one
  * $(I translation catalog) for each translation. Each catalog is an XML
	* document made visible to the framework as a string import.
  *
  * $(SECTION2 Primary Catalog)
  * The primary catalog is loaded from the string import $(D i18n/strings.xml)
  * and specifies the primary table of string resources, which is used when:
  * $(UL
  * $(LI The language of the primary table matches that of the user's
  * preferred language)
  * $(LI A translation catalog for the user's preferred language is not
  * supplied)
  * $(LI A translation catalog for the user's preferred language is supplied,
  * but does not contain a translation for the particular string being looked
  * up)
  * $(LI Internationalization is disabled))
  * The primary catalog must have the following structure:
----
$(LESS)?xml version="1.0" encoding="utf-8"?$(GREATER)
$(LESS)resources language="primary_catalog_language"$(GREATER)
	$(LESS)translation language="translation1"/$(GREATER)
	$(LESS)translation language="translation2"/$(GREATER)
	$(LESS)translation language="..."/$(GREATER)
	$(LESS)string name="id1"$(GREATER)text1$(LESS)/string$(GREATER)
	$(LESS)string name="id2"$(GREATER)text2$(LESS)/string$(GREATER)
	$(LESS)string name="..."$(GREATER)...$(LESS)/string$(GREATER)
$(LESS)/resources$(GREATER)
----
  * For the primary catalog, the root element's $(D language) attribute is
  * required and contains the language used in the primary catalog.
  * Each $(D translation) element declares that a translation catalog for the
  * given language is supplied and should be loaded.
  * All $(D language) attributes are ISO-639 language codes.
  * Each $(D string) element defines a string resource, where the $(D name)
  * attribute is the resource identifier, and the element's content is the
  * resource _text.
  *
  * $(SECTION2 Translation Catalogs)
  * Translation catalogs are loaded as string imports from
  * $(D i18n/strings.$(I ll).xml) where $(D $(I ll)) is the ISO-639 language code
  * for the language translation provided within the document. Each translation
  * must be enumerated in the primary catalog with the $(D translation) tag.
  *
  * The structure of translation catalogs is a subset of the structure of the
  * primary catalog:
----
$(LESS)?xml version="1.0" encoding="utf-8"?$(GREATER)
$(LESS)resources$(GREATER)
	$(LESS)string name="id1"$(GREATER)text1$(LESS)/string$(GREATER)
	$(LESS)string name="id2"$(GREATER)text2$(LESS)/string$(GREATER)
	$(LESS)string name="..."$(GREATER)...$(LESS)/string$(GREATER)
$(LESS)/resources$(GREATER)
----
  * Each $(D string) element provides a translation of the string resource
  * with the given identifier. The identifier must match the identifier
  * of a string resource in the primary catalog.
  *
  * $(SECTION2 String References)
  * In source code, string resources are referenced with the $(MREF strings) interface:
------
void main() {
    import std.stdio, i18n.text;
    // Writes the string resource with the identifier "hello_world" to stdout
    writeln(strings.hello_world);
}
------
  * $(SECTION2 Language Selection)
  * Platform-specific standards are used for selecting the preferred language.
  * On POSIX systems, this is the POSIX standard of using environment variables,
  * including the fallback/priority syntax supported by $(I gettext). See
  * $(HTTPS www.gnu.org/software/gettext/manual/html_node/Setting-the-POSIX-Locale.html#Setting-the-POSIX-Locale,
  * gettext's documentation on setting the POSIX locale).
  *
  * $(SECTION2 Version Identifiers)
  * The behavior of this module can be configured with version identifiers.
  * $(UL
  * $(LI $(I i18n_list_references): source code locations of string references
  * will be output during compilation)
  * $(LI $(I i18n_use_utf32): string resources are encoded in UTF-32 by default)
  * $(LI $(I i18n_use_utf16): string resources are encoded in UTF-16 by default)
  * )
  * See_Also:
  * $(I gettext)'s advice on $(HTTPS www.gnu.org/software/gettext/manual/gettext.html#Preparing-Strings, separating strings)
  * and $(HTTPS www.gnu.org/software/gettext/manual/gettext.html#Names, translating proper names)
  * Macros:
  *    SECTION2=<h3>$1</h3>
  */
module i18n.text;

private:
struct StringTable
{
	struct StringResource
	{
		string id;
		string content;
	}

	string language;
	StringResource[] strings;

	string lookup(string id) const pure nothrow @safe @nogc
	{
		import std.range : assumeSorted;

		auto lookup = strings.assumeSorted!"a.id < b.id"
			.equalRange(StringResource(id, null));

		return lookup.empty? null : lookup.front.content;
	}
}

struct Catalog
{
	struct Translation
	{
		string language, path;
	}
	Translation[] translations;
	StringTable table;
}

Catalog parseCatalog(string language, string source, StringTable parent)
{
	// Only parser for a human-readable format I could find
	// that works at compile-time
	import arsd.dom;
	import std.algorithm.sorting : sort;
	import std.exception : enforce;
	import std.format : format;
	import std.path : buildPath;

	immutable isPrimaryCatalog = language.length == 0;
	auto document = new Document(source, true, true);

	Element root;
	foreach(elem; document["resources"])
	{
		assert(root is null);
		root = elem;
	}
	enforce(root, "root element must be `resources`");

	if(isPrimaryCatalog)
	{
		enforce(root.hasAttribute("language"),
			"primary message catalog must have `language` attribute");
		language = root.getAttribute("language");
		// TODO: verify language specification
	}

	Catalog catalog;
	catalog.table.language = language;
	foreach(elem; document["resources translation"])
	{
		enforce(isPrimaryCatalog,
			"only the primary catalog can list translations");
		enforce(elem.hasAttribute("language"),
			"translation element must have `language` attribute");
		auto translationLanguage = elem.getAttribute("language");
		// TODO: verify language specification
		auto inner = elem.innerText;
		catalog.translations ~= Catalog.Translation(translationLanguage,
			buildPath("i18n", inner.length? inner :
				"strings." ~ translationLanguage ~ ".xml"));
	}

	foreach(elem; document["resources string"])
	{
		enforce(elem.hasAttribute("name"), "string resource must have name attribute");

		auto id = elem.getAttribute("name");
		enforce(id.length, "string resource name cannot be empty");
		// TODO: verify that name follows D identifier rules

		if(!isPrimaryCatalog)
			enforce(parent.lookup(id).ptr, format(
				"unknown string identifier in catalog `%s`: `%s`",
				language, id));

		catalog.table.strings ~= StringTable.StringResource(id, elem.innerText);
	}

	catalog.table.strings.sort!"a.id < b.id";
	return catalog;
}

unittest
{
	auto catalog = parseCatalog(null, q{
<?xml version="1.0" encoding="utf-8"?>
<resources language="en">
	<translation language="de"/>
	<translation language="es">spanish.xml</translation>
	<string name="foo">bar</string>
	<string name="baz">foobar</string>
</resources>
		}, StringTable.init);

	assert(catalog.table.language == "en");

	assert(catalog.translations == [
			Catalog.Translation("de", "i18n/strings.de.xml"),
			Catalog.Translation("es", "i18n/spanish.xml")
		]);

	alias S = StringTable.StringResource;
	assert(catalog.table.strings == [S("baz", "foobar"), S("foo", "bar")]);
}

struct Locale
{
	version(Posix)
		string language, country, encoding, variant;
	else
		static assert(false);
}

version(Posix)
{
	// POSIX and gettext standard
	Locale[] getLocale(Locale[] buffer) @safe
	{
		import std.algorithm : all, canFind, copy, count, find, map, splitter;
		import std.ascii : isAlpha;
		import std.process : environment;
		import std.range : chain, empty, front, only, popFront;
		import std.string : strip;

		auto lang = environment.get("LANG").strip;
		if(lang == "C")
			return null;

		// These are sorted by priority
		static immutable envVars = ["LANGUAGE", "LC_ALL", "LC_MESSAGES"];
		auto localeSearch = envVars.map!(environment.get)
			.map!strip
			.chain(only(lang))
			.find!(var => var.length);

		if(localeSearch.empty)
			return null;

		auto localeSpecs = localeSearch.front;
		if(localeSpecs == "C" || localeSpecs.front == '/')
			return null;

		static Locale parseLocale(string spec)
		{
			import std.string : lastIndexOf;
			Locale locale;
			auto index = spec.lastIndexOf('@');
			if(index != -1)
			{
				locale.variant = spec[index + 1 .. $];
				spec = spec[0 .. index];
			}
			index = spec.lastIndexOf('.');
			if(index != -1)
			{
				locale.encoding = spec[index + 1 .. $];
				spec = spec[0 .. index];
			}
			index = spec.lastIndexOf('_');
			if(index != -1)
			{
				locale.country = spec[index + 1 .. $];
				locale.language = spec[0 .. index];
			}
			else
				locale.language = spec;
			return locale;
		}

		size_t n = 0;
		foreach(localeSpec; localeSpecs.splitter(':'))
		{
			auto locale = parseLocale(localeSpec);
			if(!locale.language.empty && locale.language.all!isAlpha &&
				!buffer[0 .. n].canFind!"a.language == b.language"(locale))
			{
				buffer[n++] = locale;
				if(n == buffer.length)
					break;
			}
		}

		return buffer[0 .. n];
	}

	unittest
	{
		import std.process : environment;

		foreach(envVar; ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"])
			environment.remove(envVar);

		Locale[3] localeBuffer;

		environment["LANG"] = "en_US.UTF-8";
		assert(getLocale(localeBuffer[]) == [Locale("en", "US", "UTF-8")]);

		environment["LANG"] = "en_US";
		assert(getLocale(localeBuffer[]) == [Locale("en", "US")]);

		environment["LANG"] = "en";
		assert(getLocale(localeBuffer[]) == [Locale("en")]);

		environment["LC_MESSAGES"] = "de_DE@euro";
		assert(getLocale(localeBuffer[]) == [Locale("de", "DE", null, "euro")]);

		environment["LC_ALL"] = "ja.UTF-8";
		assert(getLocale(localeBuffer[]) == [Locale("ja", null, "UTF-8")]);

		environment["LANGUAGE"] = "en_US.UTF-8:de_DE@euro:ja.UTF-8";
		assert(getLocale(localeBuffer[]) == [
			Locale("en", "US", "UTF-8"),
			Locale("de", "DE", null, "euro"),
			Locale("ja", null, "UTF-8", null)]);

		environment["LANG"] = "C";
		assert(getLocale(localeBuffer[]) == null);
	}
}

public:

///
struct Strings()
{
	import std.algorithm.iteration : map;
	import std.algorithm.sorting : sort;
	import std.array : array;
	import std.meta : staticMap;

	static if(__VERSION__ < 2070)
		import std_backport.meta : aliasSeqOf;
	else
		import std.meta : aliasSeqOf;

	import std.path : buildPath;
	import std.range : chain, only, zip;
	import std.typecons : Tuple;
	import std.traits : isSomeString;

	private:
	enum primaryCatalog = parseCatalog(null,
		import(buildPath("i18n", "strings.xml")), StringTable.init);
	static immutable primaryTable = primaryCatalog.table;

	enum languages = primaryCatalog.translations.map!(
			(ref Catalog.Translation t) => t.language).array;
	enum paths = primaryCatalog.translations.map!(
			(ref Catalog.Translation t) => t.path).array;

	enum Import(string path) = import(path);
	enum sources = zip(languages, [staticMap!(Import, aliasSeqOf!paths)]).array;

	static if(sources.length)
	{
		static immutable translationTables = chain(only(primaryCatalog.table),
				sources.map!((ref Tuple!(string, string) pair) =>
					parseCatalog(pair.expand, primaryCatalog.table).table))
			.array
			.sort!"a.language < b.language".release();

		static immutable size_t[translationTables.length] translationIndexesBuffer;
		static immutable size_t numChosenLocales;

		static immutable(size_t)[] translationIndexes() @property pure nothrow @safe @nogc
		{
			return translationIndexesBuffer[0 .. numChosenLocales];
		}

		shared static this()
		{
			import std.algorithm : filter, map;
			import std.range : assumeSorted, empty;

			Locale[sources.length + 1] localeBuffer;
			auto locales = getLocale(localeBuffer[]);

			if(!locales.empty)
			{
				auto sortedTranslationTables = translationTables
					.assumeSorted!("a.language < b.language");

				size_t i = 0;
				foreach(translationIndex; locales.map!(locale =>
						sortedTranslationTables
							.equalRange(StringTable(locale.language)))
					.filter!(searchResult => !searchResult.empty)
					.map!(searchResult =>
						searchResult.release.ptr - translationTables.ptr))
				{
					translationIndexesBuffer[i++] = translationIndex;
				}
				numChosenLocales = i;

			}
			else
				numChosenLocales = 0;
		}
	}

	public:
	@disable this(this);

	/**
	  * Returns:
	  *   $(D true) iff id is defined in the primary catalog
	  * Complexity:
	  *   $(BIGOH log n)
	  */
	static bool identifierExists(string id) pure nothrow @safe @nogc
	{
		return primaryTable.lookup(id) != null;
	}

	private template opDispatchImpl(string id, S)
	{
		import std.conv : to;
		static immutable fallback = primaryTable.lookup(id).to!S;

		static if(sources.length)
		{
			static immutable S[sources.length + 1] translationTable =
				translationTables.map!((ref immutable StringTable table) =>
					table.lookup(id).to!S)
				.array;

			static S opDispatchImpl() @property pure nothrow @safe @nogc
			{
				foreach(index; translationIndexes)
				{
					auto text = translationTable[index];
					if(text.ptr)
						return text;
				}
				return fallback;
			}
		}
		else
			alias opDispatchImpl = fallback;
	}

	version(i18n_use_utf32)
		alias I18NString = dstring;
	else version(i18n_use_utf16)
		alias I18NString = wstring;
	else
	{
		/**
		 * Default encoding for string resources, returned by
		 * $(MREF Strings.opDispatch).
		 *
		 * Set version $(I i18n_use_utf32) to use $(D dstring), or
		 * version $(I i18n_use_utf16) to use $(D wstring); otherwise uses
		 * $(D string) (UTF-8).
		 */
		alias I18NString = string;
	}

	version(i18n_list_references)
	{
		template opDispatch(string id, string file = __FILE__, uint line = __LINE__)
			if(identifierExists(id))
		{
			alias opDispatch = getEncoded!(id, I18NString, file, line);
		}

		template getEncoded(string id, S, string file = __FILE__, uint line = __LINE__)
			if(identifierExists(id) && isSomeString!S)
		{
			import std.format : format;
			pragma(msg, format("i18n %s(%s): %s", file, line, id));
			alias getEncoded = opDispatchImpl!(id, S);
		}
	}
	else
	{
		template opDispatch(string id)
			if(identifierExists(id))
		{
			alias opDispatch = opDispatchImpl!(id, I18NString);
		}

		template getEncoded(string id, S)
			if(identifierExists(id) && isSomeString!S)
		{
			alias getEncoded = opDispatchImpl!(id, S);
		}
	}

	version(D_Ddoc)
	{
		/**
		 * Get the text for $(I id) according to the user's preferred
		 * language(s).
		 * Params:
		 *   id = identifier of string resource (the $(D name) attribute)
		 *   S = encoding for returned string, either $(D string),
		 * $(D wstring) or $(D dstring)
		 * Complexity:
		 *   $(BIGOH 1). The upper bound is proportional to the number of
		 * translations provided at compile-time. The number of string
		 * resources does $(I not) affect runtime.
		 * Example:
		 * ----
		 * void main()
		 * {
		 *     import std.stdio, i18n.text;
		 *     writeln(strings.hello_world); // Default encoding
		 *     writeln(strings.getEncoded!("hello_world", wstring)); // UTF-16
		 * }
		 * ----
		 */
		@property pure nothrow @safe @nogc
		static I18NString opDispatch(string id)()
			if(identifierExists(id));

		/// Ditto
		pure nothrow @safe @nogc
		static S getEncoded(string id, S)()
			if(identifierExists(id));
	}
}

/**
 * See_Also:
 *  $(MREF Strings)
 */
Strings!() strings()() @property pure nothrow @safe @nogc
{
	return Strings!()();
}

// Requires -Jtest
// Run with: LANGUAGE="ja_JP.UTF-8:de_DE.UTF-8"
unittest
{
	assert(strings.greeting == "今日は"); // ja
	assert(strings.yes == "ja"); // de
	assert(strings.no == "no"); // fallback to primary catalog (en)

	static assert(!__traits(compiles, strings.nonexistant));

	assert(strings.getEncoded!("greeting", dstring) == "今日は"d);
	assert(strings.getEncoded!("yes", wstring) == "ja"w);
	assert(strings.getEncoded!("no", string) == "no"c);

	static assert(!__traits(compiles,
		strings.getEncoded!("nonexistant", dstring)));
}

