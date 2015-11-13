module std_backport.meta;

import std.meta : AliasSeq;

/**
 * Converts an input range $(D range) to an alias sequence.
 */
template aliasSeqOf(alias range)
{
    import std.range : isInputRange;
    import std.traits : isArray, isNarrowString;

    alias ArrT = typeof(range);
    static if (isArray!ArrT && !isNarrowString!ArrT)
    {
        static if (range.length == 0)
        {
            alias aliasSeqOf = AliasSeq!();
        }
        else static if (range.length == 1)
        {
            alias aliasSeqOf = AliasSeq!(range[0]);
        }
        else
        {
            alias aliasSeqOf = AliasSeq!(aliasSeqOf!(range[0 .. $/2]), aliasSeqOf!(range[$/2 .. $]));
        }
    }
    else static if (isInputRange!ArrT)
    {
        import std.array : array;
        alias aliasSeqOf = aliasSeqOf!(array(range));
    }
    else
    {
        import std.string : format;
        static assert(false, format("Cannot transform %s of type %s into a AliasSeq.", range, ArrT.stringof));
    }
}
