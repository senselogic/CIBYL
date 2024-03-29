/*
    This file is part of the Cibyl distribution.

    https://github.com/senselogic/CIBYL

    Copyright (C) 2017 Eric Pelzer (ecstatic.coder@gmail.com)

    Cibyl is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3.

    Cibyl is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Cibyl.  If not, see <http://www.gnu.org/licenses/>.
*/

// -- IMPORTS

import core.stdc.stdlib : exit;
import core.thread;
import std.conv : to;
import std.datetime : Clock, SysTime;
import std.file : dirEntries, exists, mkdirRecurse, readText, timeLastModified, write, FileException, SpanMode;
import std.path : dirName;
import std.stdio : writeln;
import std.string : endsWith, indexOf, join, replace, split, startsWith, strip, stripLeft, stripRight, toUpper;

// -- TYPES

enum LANGUAGE
{
    // -- CONSTANTS

    Ruby = 1,
    Crystal = 2,
    Any = Ruby | Crystal
}

// ~~

class LINE
{
    // -- ATTRIBUTES

    long
        FirstSpaceCount,
        LastSpaceCount;
    string
        Text;
    bool
        IsRemoved;

    // -- CONSTRUCTORS

    this(
        string text
        )
    {
        long
            character_count;

        character_count = text.length;
        text = text.stripRight();

        FirstSpaceCount = text.GetSpaceCount();
        LastSpaceCount = character_count - text.length;

        Text = text[ FirstSpaceCount .. $ ];
    }

    // -- INQUIRIES

    bool IsEmpty(
        )
    {
        return Text == "";
    }

    // ~~

    bool IsCommand(
        string command,
        string[] command_prefix_array = null
        )
    {
        string
            text;

        text = Text.RemoveCommandPrefix( command_prefix_array );

        return text == command;
    }

    // ~~

    bool HasCommand(
        string command,
        string[] command_prefix_array = null
        )
    {
        string
            text;

        text = Text.RemoveCommandPrefix( command_prefix_array );

        return
            text.length >= command.length
            && text.startsWith( command )
            && ( text.length == command.length
                 || text[ command.length ] == ' ' );
    }

    // ~~

    bool HasCommand(
        string[] command_array
        )
    {
        foreach ( command; command_array )
        {
            if ( HasCommand( command ) )
            {
                return true;
            }
        }

        return false;
    }

    // ~~

    string GetIndentedText(
        )
    {
        string
            indented_text;

        if ( IsRemoved )
        {
            if ( CompactOptionIsEnabled )
            {
                return "";
            }
            else
            {
                return "\n";
            }
        }
        else
        {
            indented_text = GetSpaceText( FirstSpaceCount );
            indented_text ~= Text;
            indented_text ~= '\n';

            return indented_text;
        }
    }

    // -- OPERATIONS

    void Remove(
        )
    {
        Text = "";
        IsRemoved = true;
    }
}

// ~~

class CODE
{
    // -- ATTRIBUTES

    string
        FilePath;
    LINE[]
        LineArray;
    long
        LineIndex;

    // -- CONSTRUCTORS

    this(
        string file_path
        )
    {
        FilePath = file_path;
    }

    // -- INQUIRIES

    bool HasPriorCommand(
        string command,
        long last_line_index,
        long space_count
        )
    {
        long
            line_index;
        LINE
            line;

        for ( line_index = last_line_index;
              line_index >= 0;
              --line_index )
        {
            line = LineArray[ line_index ];

            if ( line.FirstSpaceCount < space_count
                 && line.Text != "" )
            {
                return false;
            }
            else if ( line.FirstSpaceCount == space_count
                      && line.HasCommand( command ) )
            {
                return true;
            }
        }

        return false;
    }

    // ~~

    bool FindBrace(
        ref long line_index,
        string brace,
        long first_line_index,
        long space_count
        )
    {
        LINE
            line;

        for ( line_index = first_line_index;
              line_index < LineArray.length;
              ++line_index )
        {
            line = LineArray[ line_index ];

            if ( line.FirstSpaceCount < space_count
                 && line.Text != "" )
            {
                return false;
            }
            else if ( line.FirstSpaceCount == space_count
                      && line.Text == brace )
            {
                return true;
            }
        }

        return false;
    }

    // ~~

    string GetText(
        )
    {
        string
            file_text;

        foreach ( line_index, line; LineArray )
        {
            file_text ~= line.GetIndentedText();
        }

        if ( file_text.endsWith( '\n' ) )
        {
            file_text = file_text[ 0 .. $ - 1 ] ~ GetSpaceText( LineArray[ $ - 1 ].LastSpaceCount );
        }

        return file_text;
    }

    // -- OPERATIONS

    void SetLineArray(
        string file_text
        )
    {
        string[]
            line_array;

        line_array = file_text.split( "\n" );

        foreach ( line_index; 0 .. line_array.length )
        {
            LineArray ~= new LINE( line_array[ line_index ] );
        }
    }

    // ~~

    bool ProcessBlock(
        string command,
        string[] closing_command_array,
        string[] command_prefix_array,
        LANGUAGE language
        )
    {
        long
            closing_line_index,
            opening_line_index;
        LINE
            line;

        line = LineArray[ LineIndex ];

        if ( ( Language & language ) != 0
             && line.HasCommand( command, command_prefix_array ) )
        {
            if ( FindBrace( opening_line_index, "{", LineIndex + 1, line.FirstSpaceCount )
                 && FindBrace( closing_line_index, "}", opening_line_index + 1, line.FirstSpaceCount ) )
            {
                LineArray[ opening_line_index ].Remove();

                if ( ( closing_command_array.length > 0
                       && closing_line_index + 1 < LineArray.length
                       && LineArray[ closing_line_index + 1 ].HasCommand( closing_command_array ) )
                     || command == "when"
                     || ( command == "else"
                          && HasPriorCommand( "when", LineIndex - 1, line.FirstSpaceCount ) ) )
                {
                    LineArray[ closing_line_index ].Remove();
                }
                else
                {
                    LineArray[ closing_line_index ].Text = "end";
                }

                if ( line.HasCommand( "do" )
                     && LineIndex > 0
                     && !LineArray[ LineIndex - 1 ].IsEmpty() )
                {
                    LineArray[ LineIndex - 1 ].Text ~= " \\";
                }

                return true;
            }
            else
            {
                PrintError( FilePath ~ "(" ~ ( LineIndex + 1 ).to!string() ~ ") : invalid block" );
            }
        }

        return false;
    }

    // ~~

    void ProcessBlocks(
        )
    {
        for ( LineIndex = 0;
              LineIndex < LineArray.length;
              ++LineIndex )
        {
            if ( ProcessBlock( "module", null, CommandPrefixArray, LANGUAGE.Any )
                 || ProcessBlock( "lib", null, CommandPrefixArray, LANGUAGE.Crystal )
                 || ProcessBlock( "enum", null, CommandPrefixArray, LANGUAGE.Any )
                 || ProcessBlock( "struct", null, CommandPrefixArray, LANGUAGE.Any )
                 || ProcessBlock( "class", null, CommandPrefixArray, LANGUAGE.Any )
                 || ProcessBlock( "def", [ "rescue", "else", "ensure" ], CommandPrefixArray, LANGUAGE.Any )
                 || ProcessBlock( "if", [ "elsif", "else" ], null, LANGUAGE.Any )
                 || ProcessBlock( "elsif", [ "elsif", "else" ], null, LANGUAGE.Any )
                 || ProcessBlock( "else", [ "ensure" ], null, LANGUAGE.Any )
                 || ProcessBlock( "unless", [ "else" ], null, LANGUAGE.Any )
                 || ProcessBlock( "case", [ "when", "else" ], null, LANGUAGE.Any )
                 || ProcessBlock( "when", [ "when", "else" ], null, LANGUAGE.Any )
                 || ProcessBlock( "while", null, null, LANGUAGE.Any )
                 || ProcessBlock( "until", null, null, LANGUAGE.Any )
                 || ProcessBlock( "for", null, null, LANGUAGE.Ruby )
                 || ProcessBlock( "begin", [ "rescue", "else", "ensure" ], null, LANGUAGE.Any )
                 || ProcessBlock( "rescue", [ "else", "ensure" ], null, LANGUAGE.Any )
                 || ProcessBlock( "ensure", null, null, LANGUAGE.Any )
                 || ProcessBlock( "do", null, null, LANGUAGE.Any ) )
            {
            }
        }
    }

    // ~~

    void JoinStatements(
        )
    {
        LINE
            line;
        long
            line_index;

        for ( line_index = 0;
              line_index < LineArray.length;
              ++line_index )
        {
            line = LineArray[ line_index ];

            if ( line.IsCommand( "property", CommandPrefixArray )
                 || line.IsCommand( "getter", CommandPrefixArray )
                 || line.IsCommand( "setter", CommandPrefixArray )
                 || line.IsCommand( "class_property", CommandPrefixArray )
                 || line.IsCommand( "class_getter", CommandPrefixArray )
                 || line.IsCommand( "class_setter", CommandPrefixArray ) )
            {
                line.Text ~= " \\";
            }
            else if ( line_index >= 1
                      && LineArray[ line_index - 1 ].Text != ""
                      && !LineArray[ line_index - 1 ].Text.endsWith( '\\' ) )
            {
                if ( line.HasCommand( "=" )
                     || line.HasCommand( "+=" )
                     || line.HasCommand( "-=" )
                     || line.HasCommand( "*=" )
                     || line.HasCommand( "/=" )
                     || line.HasCommand( "%=" )
                     || line.HasCommand( "**=" )
                     || line.HasCommand( "==" )
                     || line.HasCommand( "!=" )
                     || line.HasCommand( ">" )
                     || line.HasCommand( "<" )
                     || line.HasCommand( ">=" )
                     || line.HasCommand( "<=" )
                     || line.HasCommand( "<=>" )
                     || line.HasCommand( "===" )
                     || line.HasCommand( "+" )
                     || line.HasCommand( "-" )
                     || line.HasCommand( "*" )
                     || line.HasCommand( "/" )
                     || line.HasCommand( "%" )
                     || line.HasCommand( "**" )
                     || line.HasCommand( "&" )
                     || line.HasCommand( "|" )
                     || line.HasCommand( "^" )
                     || line.HasCommand( "<<" )
                     || line.HasCommand( ">>" )
                     || line.HasCommand( "&&" )
                     || line.HasCommand( "||" )
                     || ( ( Language & LANGUAGE.Ruby ) != 0
                          && ( line.HasCommand( "and" )
                               || line.HasCommand( "or" ) ) ) )
                {
                    LineArray[ line_index - 1 ].Text ~= " \\";
                }
            }
        }
    }

    // ~~

    void Process(
        bool blocks_are_processed = true
        )
    {
        if ( blocks_are_processed )
        {
            ProcessBlocks();
        }

        if ( JoinOptionIsEnabled )
        {
            JoinStatements();
        }
    }
}

// ~~

class CONTEXT
{
    // -- ATTRIBUTES

    long
        BraceLevel;
    bool
        IsInsideShortComment,
        IsInsideLongComment,
        IsInsideString,
        IsInsideInterpolatedString,
        IsInsideInterpolatedExpression;
    char
        OpeningDelimiter,
        ClosingDelimiter;
    long
        DelimiterLevel;
}

// ~~

class FILE
{
    // -- ATTRIBUTES

    string
        InputPath,
        OutputPath;
    bool
        Exists;
    SysTime
        SystemTime;
    bool
        UsesCarriageReturn;

    // -- CONSTRUCTORS

    this(
        string input_file_path
        )
    {
        InputPath = input_file_path;
        OutputPath = "";
        Exists = false;
    }

    // ~~

    this(
        string input_file_path,
        string output_file_path
        )
    {
        InputPath = input_file_path;
        OutputPath = output_file_path;
        Exists = true;
    }

    // -- INQUIRIES

    bool HasChanged(
        )
    {
        SysTime
            old_system_time;

        old_system_time = SystemTime;

        try
        {
            SystemTime = InputPath.timeLastModified();
        }
        catch ( FileException file_exception )
        {
            Abort( "Can't read file : " ~ InputPath, file_exception );
        }

        if ( !Exists )
        {
            Exists = true;

            return true;
        }
        else
        {
            return SystemTime > old_system_time;
        }
    }

    // -- OPERATIONS

    string ReadInputFile(
        )
    {
        string
            input_file_text;

        writeln( "Reading file : ", InputPath );

        try
        {
            input_file_text = InputPath.readText();
        }
        catch ( FileException file_exception )
        {
            Abort( "Can't read file : " ~ InputPath, file_exception );
        }

        UsesCarriageReturn = ( input_file_text.indexOf( '\r' ) >= 0 );

        if ( UsesCarriageReturn )
        {
            input_file_text = input_file_text.replace( "\r", "" );
        }

        return input_file_text.replace( "\t", GetSpaceText( TabulationSpaceCount ) );
    }

    // ~~

    void CreateOutputFolder(
        )
    {
        string
            output_folder_path;

        output_folder_path = OutputPath.dirName();

        if ( !output_folder_path.exists() )
        {
            writeln( "Creating folder : ", output_folder_path );

            try
            {
                if ( output_folder_path != ""
                     && output_folder_path != "/"
                     && !output_folder_path.exists() )
                {
                    output_folder_path.mkdirRecurse();
                }
            }
            catch ( FileException file_exception )
            {
                Abort( "Can't create folder : " ~ output_folder_path, file_exception );
            }
        }
    }

    // ~~

    void WriteOutputFile(
        string output_file_text
        )
    {
        writeln( "Writing file : ", OutputPath );

        if ( UsesCarriageReturn )
        {
            output_file_text = output_file_text.replace( "\n", "\r\n" );
        }

        try
        {
            OutputPath.write( output_file_text );
        }
        catch ( FileException file_exception )
        {
            Abort( "Can't write file : " ~ OutputPath, file_exception );
        }
    }

    // ~~

    void LoadDictionary(
        )
    {
        string[]
            identifier_array,
            line_array;

        line_array = ReadInputFile().split( "\n" );

        foreach ( line_index, line; line_array )
        {
            line = line.strip();

            if ( line.length > 0 )
            {
                identifier_array = line.split( ':' );

                if ( identifier_array.length == 2 )
                {
                    ReplacedIdentifierMap[ identifier_array[ 0 ].strip() ] = identifier_array[ 1 ].strip();
                }
                else if ( identifier_array.length == 1 )
                {
                    ReplacedIdentifierMap[ identifier_array[ 0 ].strip() ] = identifier_array[ 0 ].strip();
                }
                else
                {
                    PrintError( "Invalid definition : " ~ line );
                }
            }
        }
    }

    // ~~

    string ProcessIdentifiers(
        string text,
        long line_index
        )
    {
        char
            character;
        string
            identifier;
        string *
            replaced_identifier;
        CONTEXT
            context;
        CONTEXT[]
            context_array;
        long
            character_index,
            escaped_character_index,
            line_character_index,
            line_first_character_index,
            long_comment_space_count,
            next_character_index,
            space_count;

        context = new CONTEXT();
        context_array ~= context;

        line_first_character_index = 0;
        escaped_character_index = -1;
        long_comment_space_count = 0;

        for ( character_index = 0;
              character_index < text.length;
              ++character_index )
        {
            character = text[ character_index ];
            line_character_index = character_index - line_first_character_index;

            if ( character == '\n' )
            {
                line_first_character_index = character_index + 1;

                ++line_index;
            }

            if ( context.IsInsideShortComment )
            {
                if ( character == '\n' )
                {
                    context.IsInsideShortComment = false;
                }
            }
            else if ( context.IsInsideLongComment )
            {
                if ( line_character_index == long_comment_space_count )
                {
                    if ( character == ' '
                         && character_index + 1 < text.length
                         && text[ character_index + 1 ] == ' ' )
                    {
                        text = text[ 0 .. character_index ] ~ text[ character_index + 2 .. $ ];
                    }

                    text = text[ 0 .. character_index ] ~ "#" ~ text[ character_index .. $ ];
                }
                else if ( character == '*'
                          && character_index + 1 < text.length
                          && text[ character_index + 1 ] == '/' )
                {
                    context.IsInsideLongComment = false;

                    text = text[ 0 .. character_index ] ~ text[ character_index + 2 .. $ ];

                    --character_index;

                    if ( character_index + 1 < text.length
                         && text[ character_index + 1 ] != '\n' )
                    {
                        for ( next_character_index = character_index + 1;
                              next_character_index < text.length
                              && text[ next_character_index ] != '\n';
                              ++next_character_index )
                        {
                            if ( text[ next_character_index ] != ' ' )
                            {
                                PrintError( InputPath ~ "(" ~ ( line_index + 1 ).to!string() ~ ") : long comment not ending line" );

                                break;
                            }
                        }
                    }
                }
                else if ( character != ' '
                          && line_character_index < long_comment_space_count )
                {
                    space_count = long_comment_space_count - line_character_index;

                    text = text[ 0 .. character_index ] ~ GetSpaceText( space_count ) ~ text[ character_index .. $ ];

                    if ( character == '\n' )
                    {
                        character_index += space_count;

                        text = text[ 0 .. character_index ] ~ "#" ~ text[ character_index .. $ ];
                        ++character_index;

                        line_first_character_index = character_index + 1;
                    }
                    else
                    {
                        character_index += space_count - 1;
                    }
                }
            }
            else if ( !context.IsInsideString
                      && character == '/'
                      && character_index + 1 < text.length
                      && text[ character_index + 1 ] == '/' )
            {
                context.IsInsideShortComment = true;

                text = text[ 0 .. character_index ] ~ '#' ~ text[ character_index + 2 .. $ ];
            }
            else if ( !context.IsInsideString
                      && character == '/'
                      && character_index + 1 < text.length
                      && text[ character_index + 1 ] == '*' )
            {
                context.IsInsideLongComment = true;

                text = text[ 0 .. character_index ] ~ '#' ~ text[ character_index + 2 .. $ ];

                long_comment_space_count = line_character_index;
            }
            else if ( !context.IsInsideString
                      && character == '\\' )
            {
                text = text[ 0 .. character_index ] ~ text [ character_index + 1 .. $ ];

                while ( character_index + 1 < text.length
                        && text[ character_index ].IsAlphaNumericCharacter()
                        && text[ character_index + 1 ].IsAlphaNumericCharacter() )
                {
                    ++character_index;
                }

                escaped_character_index = character_index;
            }
            else if ( context.IsInsideString
                      && character == '\\' )
            {
                ++character_index;
            }
            else if ( context.IsInsideInterpolatedString
                      && character == '#'
                      && character_index + 1 < text.length
                      && text[ character_index + 1 ] == '{' )
            {
                context = new CONTEXT();
                context.IsInsideInterpolatedExpression = true;
                context.BraceLevel = 1;
                context_array ~= context;

                ++character_index;
            }
            else if ( context.IsInsideString
                      && character == context.OpeningDelimiter )
            {
                ++context.DelimiterLevel;
            }
            else if ( context.IsInsideString
                      && character == context.ClosingDelimiter )
            {
                --context.DelimiterLevel;

                if ( context.DelimiterLevel == 0 )
                {
                    context.IsInsideString = false;
                    context.IsInsideInterpolatedString = false;
                    context.OpeningDelimiter = 0;
                    context.ClosingDelimiter = 0;
                }
            }
            else if ( !context.IsInsideString
                      && character == '{' )
            {
                ++context.BraceLevel;
            }
            else if ( !context.IsInsideString
                      && character == '}' )
            {
                --context.BraceLevel;

                if ( context.IsInsideInterpolatedExpression
                     && context.BraceLevel == 0 )
                {
                    context_array = context_array[ 0 .. $ - 1 ];
                    context = context_array[ $ - 1 ];
                }
            }
            else if ( !context.IsInsideString
                      && character == '\'' )
            {
                context.IsInsideString = true;
                context.IsInsideInterpolatedString = false;
                context.OpeningDelimiter = 0;
                context.ClosingDelimiter = '\'';
                context.DelimiterLevel = 1;
            }
            else if ( !context.IsInsideString
                      && character == '"' )
            {
                context.IsInsideString = true;
                context.IsInsideInterpolatedString = true;
                context.OpeningDelimiter = 0;
                context.ClosingDelimiter = '"';
                context.DelimiterLevel = 1;
            }
            else if ( !context.IsInsideString
                      && character == '%'
                      && character_index + 1 < text.length
                      && "([{<|".indexOf( text[ character_index + 1 ] ) >= 0 )
            {
                context.IsInsideString = true;
                context.IsInsideInterpolatedString = true;
                context.OpeningDelimiter = text[ character_index + 1 ];
                context.ClosingDelimiter = ")]}>|"[ "([{<|".indexOf( context.OpeningDelimiter ) ];
                context.DelimiterLevel = 1;

                if ( context.OpeningDelimiter == context.ClosingDelimiter )
                {
                    context.OpeningDelimiter = 0;
                }

                ++character_index;
            }
            else if ( !context.IsInsideString
                      && character == '%'
                      && character_index + 2 < text.length
                      && ( text[ character_index + 1 ] == 'q'
                           || text[ character_index + 1 ] == 'Q' )
                      && "([{<|".indexOf( text[ character_index + 2 ] ) >= 0 )
            {
                context.IsInsideString = true;
                context.IsInsideInterpolatedString = ( text[ character_index + 1 ] == 'Q' );
                context.OpeningDelimiter = text[ character_index + 2 ];
                context.ClosingDelimiter = ")]}>|"[ "([{<|".indexOf( context.OpeningDelimiter ) ];
                context.DelimiterLevel = 1;

                if ( context.OpeningDelimiter == context.ClosingDelimiter )
                {
                    context.OpeningDelimiter = 0;
                }

                character_index += 2;
            }
            else if ( ( ( character >= 'a' && character <= 'z' )
                          || ( character >= 'A' && character <= 'Z' ) )
                        && ( character_index == 0
                             || !text[ character_index - 1 ].IsAlphaNumericCharacter() ) )
            {
                next_character_index = character_index + 1;

                while ( next_character_index < text.length
                        && text[ next_character_index ].IsAlphaNumericCharacter() )
                {
                    ++next_character_index;
                }

                if ( next_character_index < text.length
                     && ( text[ next_character_index ] == '!'
                          || text[ next_character_index ] == '?' ) )
                {
                    ++next_character_index;
                }

                identifier = text[ character_index .. next_character_index ];

                if ( !context.IsInsideString )
                {
                    if ( ConvertOptionIsEnabled
                         && character_index >= 1
                         && character_index - 1 != escaped_character_index
                         && text[ character_index - 1 ] == '#' )
                    {
                        if ( identifier.IsLowerCaseIdentifier() )
                        {
                            identifier = identifier.toUpper().GetPascalCaseIdentifier();
                        }
                        else
                        {
                            identifier = identifier.GetSnakeCaseIdentifier().toUpper();
                        }

                        text = text[ 0 .. character_index - 1 ] ~ identifier ~ text [ next_character_index .. $ ];

                        character_index = character_index + identifier.length - 2;
                    }
                    else
                    {
                        if ( ConvertOptionIsEnabled
                             && character_index >= 1
                             && character_index - 1 != escaped_character_index
                             && text[ character_index - 1 ] == '$' )
                        {
                            text = text[ 0 .. character_index - 1 ] ~ "@@" ~ text [ character_index .. $ ];

                            ++character_index;
                            ++next_character_index;
                        }

                        replaced_identifier = identifier in ReplacedIdentifierMap;

                        if ( ReplaceOptionIsEnabled
                             && replaced_identifier !is null )
                        {
                            text = text[ 0 .. character_index ] ~ *replaced_identifier ~ text [ next_character_index .. $ ];

                            character_index = character_index + replaced_identifier.length - 1;
                        }
                        else if ( ConvertOptionIsEnabled
                                  && ( character >= 'A' && character <= 'Z' ) )
                        {
                            if ( identifier.IsUpperCaseIdentifier()
                                 && identifier.length > 1 )
                            {
                                identifier = identifier.GetPascalCaseIdentifier();
                            }
                            else
                            {
                                identifier = identifier.GetSnakeCaseIdentifier();
                            }

                            text = text[ 0 .. character_index ] ~ identifier ~ text [ next_character_index .. $ ];

                            character_index = character_index + identifier.length - 1;
                        }
                        else
                        {
                            character_index = next_character_index - 1;
                        }
                    }
                }
                else
                {
                    character_index = next_character_index - 1;
                }
            }
        }

        return text;
    }

    // ~~

    string ProcessText(
        string text,
        bool blocks_are_processed,
        long line_index
        )
    {
        CODE
            code;

        text = ProcessIdentifiers( text, line_index );

        code = new CODE( InputPath );
        code.SetLineArray( text );
        code.Process( blocks_are_processed );

        return code.GetText();
    }

    // ~~

    string EscapeText(
        string text
        )
    {
        if ( text.startsWith( '~' )
             || text.startsWith( "-~" ) )
        {
            if ( text.startsWith( '~' ) )
            {
                text = "= HTML.escape(" ~ text[ 1 .. $ ];
            }
            else
            {
                text = "-= HTML.escape(" ~ text[ 2 .. $ ];
            }

            if ( text.endsWith( '-' ) )
            {
                text = text[ 0 .. $ - 1 ] ~ ") -";
            }
            else
            {
                text ~= ") ";
            }
        }

        return text;
    }

    // ~~

    string ProcessEmbeddedText(
        string text
        )
    {
        string
            processed_text;
        long
            character_index,
            line_count,
            line_index,
            next_character_index;

        line_index = 0;

        for ( character_index = 0;
              character_index < text.length;
              ++character_index )
        {
            if ( text[ character_index ] == '\n' )
            {
                ++line_index;
            }
            else if ( text[ character_index ] == '<'
                 && character_index + 1 < text.length
                 && text[ character_index + 1 ] == '%' )
            {
                if ( character_index + 2 < text.length
                     && text[ character_index + 2 ] == '%' )
                {
                    character_index += 2;
                }
                else
                {
                    line_count = 0;

                    for ( next_character_index = character_index + 2;
                          next_character_index < text.length;
                          ++next_character_index )
                    {
                        if ( text[ next_character_index ] == '\n' )
                        {
                            ++line_count;
                        }
                        else if ( text[ next_character_index ] == '%'
                                  && next_character_index + 1 < text.length
                                  && text[ next_character_index + 1 ] == '>' )
                        {
                            character_index += 2;

                            processed_text = EscapeText( ProcessText( text[ character_index .. next_character_index ], false, line_index ) );

                            text = text[ 0 .. character_index ] ~ processed_text ~ text[ next_character_index .. $ ];

                            next_character_index = character_index + processed_text.length + 2;

                            break;
                        }
                    }

                    character_index = next_character_index - 1;
                    line_index += line_count;
                }
            }
        }

        return text;
    }

    // ~~

    void Process(
        bool modification_time_is_used
        )
    {
        string
            text;

        if ( Exists
             && ( !OutputPath.exists()
                  || !modification_time_is_used
                  || InputPath.timeLastModified() > OutputPath.timeLastModified() ) )
        {
            text = ReadInputFile();

            if ( InputPath.endsWith( ".cb" ) )
            {
                text = ProcessText( text, true, 0 );
            }
            else if ( InputPath.endsWith( ".ecb" ) )
            {
                text = ProcessEmbeddedText( text );
            }

            if ( CreateOptionIsEnabled )
            {
                CreateOutputFolder();
            }

            WriteOutputFile( text );
        }
    }
}

// -- VARIABLES

bool
    CompactOptionIsEnabled,
    ConvertOptionIsEnabled,
    CreateOptionIsEnabled,
    JoinOptionIsEnabled,
    ReplaceOptionIsEnabled,
    WatchOptionIsEnabled;
string
    InputFolderPath,
    OutputFolderPath,
    SpaceText;
string[ string ]
    ReplacedIdentifierMap;
FILE[]
    DictionaryFileArray;
FILE[ string ]
    FileMap;
long
    PauseDuration,
    TabulationSpaceCount;
LANGUAGE
    Language;
string[]
    CommandPrefixArray = [ "private ", "protected ", "abstract " ];

// -- FUNCTIONS

void PrintError(
    string message
    )
{
    writeln( "*** ERROR : ", message );
}

// ~~

void Abort(
    string message
    )
{
    PrintError( message );

    exit( -1 );
}

// ~~

void Abort(
    string message,
    FileException file_exception
    )
{
    PrintError( message );
    PrintError( file_exception.msg );

    exit( -1 );
}

// ~~

long GetSpaceCount(
    string text
    )
{
    long
        space_count;

    space_count = 0;

    while ( space_count < text.length
            && text[ space_count ] == ' ' )
    {
        ++space_count;
    }

    return space_count;
}

// ~~

string GetSpaceText(
    long space_count
    )
{
    if ( space_count <= 0 )
    {
        return "";
    }
    else
    {
        while ( SpaceText.length < space_count )
        {
            SpaceText ~= SpaceText;
        }

        return SpaceText[ 0 .. space_count ];
    }
}

// ~~

string GetLogicalPath(
    string path
    )
{
    return path.replace( '\\', '/' );
}

// ~~

string RemoveCommandPrefix(
    string text,
    string[] command_prefix_array
    )
{
    text = text.stripLeft();

    foreach ( command_prefix; command_prefix_array )
    {
        if ( text.startsWith( command_prefix ) )
        {
            text = text[ command_prefix.length .. $ ].stripLeft();
        }
    }

    return text;
}

// ~~

bool IsAlphaNumericCharacter(
    char character
    )
{
    return
        ( character >= 'A' && character <= 'Z' )
        || ( character >= 'a' && character <= 'z' )
        || ( character >= '0' && character <= '9' )
        || character == '_';
}

// ~~

bool IsLowerCaseIdentifier(
    string text
    )
{
    foreach ( character; text )
    {
        if ( character >= 'A' && character <= 'Z' )
        {
            return false;
        }
    }

    return true;
}

// ~~

bool IsUpperCaseIdentifier(
    string text
    )
{
    foreach ( character; text )
    {
        if ( character >= 'a' && character <= 'z' )
        {
            return false;
        }
    }

    return true;
}

// ~~

string GetPascalCaseIdentifier(
    string text
    )
{
    char
        character;
    string
        pascal_case_identifier;
    long
        character_index;

    for ( character_index = 0;
          character_index < text.length;
          ++character_index )
    {
        character = text[ character_index ];

        if ( character == '_'
             && character_index + 1 < text.length )
        {
            ++character_index;

            pascal_case_identifier ~= text[ character_index ];
        }
        else if ( character_index > 0
                  && character >= 'A'
                  && character <= 'Z' )
        {
            pascal_case_identifier ~= ( character - 'A' ) + 'a';
        }
        else
        {
            pascal_case_identifier ~= character;
        }
    }

    return pascal_case_identifier;
}

// ~~

string GetSnakeCaseIdentifier(
    string text
    )
{
    string
        snake_case_identifier;

    foreach ( character_index, character; text )
    {
        if ( character >= 'A'
             && character <= 'Z' )
        {
            if ( character_index > 0 )
            {
                snake_case_identifier ~= '_';
            }

            snake_case_identifier ~= ( character - 'A' ) + 'a';
        }
        else
        {
            snake_case_identifier ~= character;
        }
    }

    return snake_case_identifier;
}

// ~~

bool LoadDictionaries(
    )
{
    bool
        dictionaries_are_loaded;

    dictionaries_are_loaded = false;

    foreach ( dictionary_file; DictionaryFileArray )
    {
        if ( dictionary_file.HasChanged() )
        {
            dictionaries_are_loaded = true;
        }
    }

    if ( dictionaries_are_loaded )
    {
        ReplacedIdentifierMap = null;

        foreach ( dictionary_file; DictionaryFileArray )
        {
            dictionary_file.LoadDictionary();
        }
    }

    return dictionaries_are_loaded;
}

// ~~

void FindFiles(
    string input_folder_path,
    string output_folder_path
    )
{
    string
        input_file_path,
        output_file_path;
    FILE *
        found_file;

    foreach ( ref old_file; FileMap )
    {
        old_file.Exists = false;
    }

    foreach ( input_file_extension; [ ".cb", ".ecb" ] )
    {
        foreach ( input_folder_entry; dirEntries( input_folder_path, "*" ~ input_file_extension, SpanMode.depth ) )
        {
            if ( input_folder_entry.isFile )
            {
                input_file_path = input_folder_entry.name;

                if ( input_file_path.startsWith( input_folder_path )
                     && input_file_path.endsWith( input_file_extension ) )
                {
                    output_file_path
                        = output_folder_path
                          ~ input_file_path[ input_folder_path.length .. $ - input_file_extension.length ];

                    if ( input_file_extension == ".cb" )
                    {
                        if ( Language == LANGUAGE.Ruby )
                        {
                            output_file_path ~= ".rb";
                        }
                        else if ( Language == LANGUAGE.Crystal )
                        {
                            output_file_path ~= ".cr";
                        }
                    }
                    else if ( input_file_extension == ".ecb" )
                    {
                        if ( Language == LANGUAGE.Ruby )
                        {
                            output_file_path ~= ".erb";
                        }
                        else if ( Language == LANGUAGE.Crystal )
                        {
                            output_file_path ~= ".ecr";
                        }
                    }

                    found_file = input_file_path in FileMap;

                    if ( found_file is null )
                    {
                        FileMap[ input_file_path ] = new FILE( input_file_path, output_file_path );
                    }
                    else
                    {
                        found_file.Exists = true;
                    }
                }
            }
        }
    }
}

// ~~

void ProcessFiles(
    string input_folder_path,
    string output_folder_path,
    bool modification_time_is_used
    )
{
    if ( LoadDictionaries() )
    {
        modification_time_is_used = false;
    }

    FindFiles( input_folder_path, output_folder_path );

    foreach ( ref file; FileMap )
    {
        file.Process( modification_time_is_used );
    }
}

// ~~

void WatchFiles(
    string input_folder_path,
    string output_folder_path
    )
{
    ProcessFiles( input_folder_path, output_folder_path, false );

    writeln( "Watching files..." );

    while ( true )
    {
        Thread.sleep( dur!( "msecs" )( PauseDuration ) );

        ProcessFiles( input_folder_path, output_folder_path, true );
    }
}

// ~~

void main(
    string[] argument_array
    )
{
    string
        input_folder_path,
        option,
        output_folder_path;

    argument_array = argument_array[ 1 .. $ ];

    SpaceText = " ";

    Language = LANGUAGE.Ruby;
    ReplaceOptionIsEnabled = false;
    ConvertOptionIsEnabled = false;
    JoinOptionIsEnabled = false;
    CompactOptionIsEnabled = false;
    CreateOptionIsEnabled = false;
    WatchOptionIsEnabled = false;
    PauseDuration = 500;
    TabulationSpaceCount = 4;

    while ( argument_array.length >= 1
            && argument_array[ 0 ].startsWith( "--" ) )
    {
        option = argument_array[ 0 ];

        argument_array = argument_array[ 1 .. $ ];

        if ( option == "--ruby" )
        {
            Language = LANGUAGE.Ruby;
        }
        else if ( option == "--crystal" )
        {
            Language = LANGUAGE.Crystal;
        }
        else if ( option == "--replace"
                  && argument_array.length >= 1 )
        {
            ReplaceOptionIsEnabled = true;

            DictionaryFileArray ~= new FILE( argument_array[ 0 ].GetLogicalPath() );

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--convert" )
        {
            ConvertOptionIsEnabled = true;
        }
        else if ( option == "--join" )
        {
            JoinOptionIsEnabled = true;
        }
        else if ( option == "--compact" )
        {
            CompactOptionIsEnabled = true;
        }
        else if ( option == "--create" )
        {
            CreateOptionIsEnabled = true;
        }
        else if ( option == "--watch" )
        {
            WatchOptionIsEnabled = true;
        }
        else if ( option == "--pause"
                  && argument_array.length >= 1 )
        {
            PauseDuration = argument_array[ 0 ].to!long();

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--tabulation"
                  && argument_array.length >= 1 )
        {
            TabulationSpaceCount = argument_array[ 0 ].to!long();

            argument_array = argument_array[ 1 .. $ ];
        }
        else
        {
            PrintError( "Invalid option : " ~ option );
        }
    }

    if ( argument_array.length == 2
         && argument_array[ 0 ].GetLogicalPath().endsWith( '/' )
         && argument_array[ 1 ].GetLogicalPath().endsWith( '/' ) )
    {
        input_folder_path = argument_array[ 0 ].GetLogicalPath();
        output_folder_path = argument_array[ 1 ].GetLogicalPath();

        if ( WatchOptionIsEnabled )
        {
            WatchFiles( input_folder_path, output_folder_path );
        }
        else
        {
            ProcessFiles( input_folder_path, output_folder_path, false );
        }
    }
    else
    {
        writeln( "Usage :" );
        writeln( "    cibyl [options] INPUT_FOLDER/ OUTPUT_FOLDER/" );
        writeln( "Options :" );
        writeln( "    --ruby" );
        writeln( "    --crystal" );
        writeln( "    --replace dictionary.txt" );
        writeln( "    --convert" );
        writeln( "    --join" );
        writeln( "    --compact" );
        writeln( "    --create" );
        writeln( "    --watch" );
        writeln( "    --pause 500" );
        writeln( "    --tabulation 4" );
        writeln( "Examples :" );
        writeln( "    cibyl --crystal CB/ CR/" );
        writeln( "    cibyl --crystal --create CB/ CR/" );
        writeln( "    cibyl --crystal --create --watch CB/ CR/" );

        PrintError( "Invalid arguments : " ~ argument_array.to!string() );
    }
}
