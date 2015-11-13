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
  * The structure of translation catalogs is a subset of the structre of the
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
  * See_Also:
  * $(I gettext)'s advice on $(HTTPS www.gnu.org/software/gettext/manual/gettext.html#Preparing-Strings, separating strings)
  * and $(HTTPS www.gnu.org/software/gettext/manual/gettext.html#Names, translating names)
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
	Locale[] getLocale() @safe
	{
		import std.algorithm : copy, count, find, map, splitter;
		import std.process : environment;
		import std.range : chain, front, only, popFront;
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

		auto localeSpec = localeSearch.front;
		if(localeSpec == "C" || localeSpec.front == '/')
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

		auto locales = new Locale[](localeSpec.count(':') + 1);
		localeSpec.splitter(':').map!parseLocale.copy(locales);
		return locales;
	}

	unittest
	{
		import std.process :environment;

		foreach(envVar; ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"])
			environment.remove(envVar);

		environment["LANG"] = "en_US.UTF-8";
		assert(getLocale() == [Locale("en", "US", "UTF-8")]);

		environment["LANG"] = "en_US";
		assert(getLocale() == [Locale("en", "US")]);

		environment["LANG"] = "en";
		assert(getLocale() == [Locale("en")]);

		environment["LC_MESSAGES"] = "de_DE@euro";
		assert(getLocale() == [Locale("de", "DE", null, "euro")]);

		environment["LC_ALL"] = "ja.UTF-8";
		assert(getLocale() == [Locale("ja", null, "UTF-8")]);

		environment["LANGUAGE"] = "en_US.UTF-8:de_DE@euro:ja.UTF-8";
		assert(getLocale() == [
			Locale("en", "US", "UTF-8"),
			Locale("de", "DE", null, "euro"),
			Locale("ja", null, "UTF-8", null)]);

		environment["LANG"] = "C";
		assert(getLocale() == null);
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

			auto locales = getLocale();

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

	///
	template opDispatch(string id, string file = __FILE__, uint line = __LINE__)
		if(identifierExists(id))
	{
		version(i18n_list_references)
		{
			import std.format : format;
			pragma(msg, format("i18n %s(%s): %s", file, line, id));
		}

		static immutable fallback = primaryTable.lookup(id);

		static if(sources.length)
		{
			static immutable translationTable = translationTables.map!(
				(ref immutable StringTable table) => table.lookup(id))
				.array;

			/**
			  * Get the text for $(I id) according to the user's
			  * preferred language(s).
			  * Complexity:
			  *   $(BIGOH 1)
			  */
			string opDispatch() @property pure nothrow @safe @nogc
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
			alias opDispatch = fallback;
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

