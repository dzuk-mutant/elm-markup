module Mark.Error exposing (Error, Text, Theme(..), toHtml, toJson, toString)

{-| -}

-- import Json.Decode as Decode
-- import Json.Encode as Json

import Html
import Html.Attributes
import Mark
import Parser.Advanced as Parser


{-| -}



-- toJson : String -> List (Parser.DeadEnd Mark.Context Mark.Problem) -> List Error


toJson source errors =
    errors
        |> List.foldl mergeErrors []
        |> List.map (renderErrors (String.lines source))



-- toString source errors =
--     toJson source errors
--         |>


{-| -}
toString : String -> List (Parser.DeadEnd Mark.Context Mark.Problem) -> List String
toString source errors =
    errors
        |> List.foldl mergeErrors []
        |> List.map (errorToString << renderErrors (String.lines source))


errorToString error =
    String.toUpper error.title
        ++ "\n\n"
        ++ String.join "" (List.map .text error.message)


type Theme
    = Dark
    | Light


toHtml theme source errors =
    errors
        |> List.foldl mergeErrors []
        |> List.map (errorToHtml theme << renderErrors (String.lines source))


errorToHtml theme error =
    Html.div []
        (Html.span [ Html.Attributes.style "color" (foregroundClr theme) ]
            [ Html.text
                (String.toUpper error.title
                    ++ "\n\n"
                )
            ]
            :: List.map (renderMessageHtml theme) error.message
        )


redClr theme =
    case theme of
        Dark ->
            "#ef2929"

        Light ->
            "#cc0000"



-- "rgba(199,26,0, 0.9)"
-- yellowClr =
-- "rgba(199,197,1, 0.9)"


yellowClr theme =
    case theme of
        Dark ->
            "#edd400"

        Light ->
            "#c4a000"


foregroundClr theme =
    case theme of
        Dark ->
            -- "rgba(197,197,197,0.9)"
            "#eeeeec"

        Light ->
            "rgba(16,16,16, 0.9)"


renderMessageHtml theme message =
    Html.span
        (List.filterMap identity
            [ if message.bold then
                Just (Html.Attributes.style "font-weight" "bold")

              else
                Nothing
            , if message.underline then
                Just (Html.Attributes.style "text-decoration" "underline")

              else
                Nothing
            , case message.color of
                Nothing ->
                    Just <| Html.Attributes.style "color" (foregroundClr theme)

                Just "red" ->
                    Just <| Html.Attributes.style "color" (redClr theme)

                Just "yellow" ->
                    Just <| Html.Attributes.style "color" (yellowClr theme)

                _ ->
                    Nothing
            ]
        )
        [ Html.text message.text ]


type alias Message =
    { row : Int
    , col : Int
    , problem : Problem
    }


type alias Text =
    { text : String
    , bold : Bool
    , underline : Bool
    , color : Maybe String
    }


type alias Error =
    { message : List Text
    , region : { start : Position, end : Position }
    , title : String
    }


type alias Position =
    { line : Int
    , column : Int
    }


{-| -}
type Problem
    = UnknownBlock (List String)
    | UnknownInline (List String)
    | NonMatchingFields
        { expecting : List String
        , found : List String
        }
    | UnexpectedField
        { found : String
        , options : List String
        , recordName : String
        }
    | ExpectingIndent Int
    | CantStartTextWithSpace
    | UnclosedStyle (List Mark.Style)
    | BadDate String
    | IntOutOfRange
        { found : Int
        , min : Int
        , max : Int
        }
    | FloatOutOfRange
        { found : Float
        , min : Float
        , max : Float
        }


type alias Similarity =
    Int


similarity : String -> String -> Similarity
similarity source target =
    let
        length =
            if String.length source == String.length target then
                1

            else
                0

        first str =
            Maybe.map (String.fromChar << Tuple.first) (String.uncons str)
                |> Maybe.withDefault ""

        last str =
            Maybe.map (String.fromChar << Tuple.first) (String.uncons (String.reverse str))
                |> Maybe.withDefault

        firstChar =
            if first source == first target then
                1

            else
                0

        lastChar =
            if first source == first target then
                1

            else
                0

        addCompared ( x, y ) total =
            if x == y then
                total + 1

            else
                total
    in
    -- List.foldl (+) 0 [ length, firstChar, lastChar ]
    List.foldl addCompared 0 (List.map2 Tuple.pair (String.toList source) (String.toList target))


getRemap context found =
    case found of
        Nothing ->
            case context.context of
                Mark.InRemapped remapped ->
                    Just remapped

                _ ->
                    found

        _ ->
            found


getErrorPosition current =
    case List.foldl getRemap Nothing current.contextStack of
        Nothing ->
            ( current.row, current.col )

        Just remap ->
            ( remap.line, remap.column )


mergeErrors current merged =
    let
        ( row, col ) =
            getErrorPosition current
    in
    case merged of
        [] ->
            case current.problem of
                Mark.ExpectingBlockName block ->
                    [ { row = row
                      , col = col
                      , problem =
                            UnknownBlock [ block ]
                      }
                    ]

                Mark.ExpectingInlineName inline ->
                    [ { row = row
                      , col = col
                      , problem =
                            UnknownInline [ inline ]
                      }
                    ]

                Mark.NonMatchingFields fields ->
                    [ { row = row
                      , col = col
                      , problem =
                            NonMatchingFields fields
                      }
                    ]

                Mark.UnexpectedField fields ->
                    [ { row = row
                      , col = col
                      , problem =
                            UnexpectedField fields
                      }
                    ]

                Mark.ExpectingIndent indentation ->
                    [ { row = row
                      , col = col
                      , problem =
                            ExpectingIndent indentation
                      }
                    ]

                Mark.CantStartTextWithSpace ->
                    [ { row = row
                      , col = col
                      , problem =
                            CantStartTextWithSpace
                      }
                    ]

                Mark.UnclosedStyles styles ->
                    [ { row = row
                      , col = col
                      , problem =
                            UnclosedStyle styles
                      }
                    ]

                Mark.BadDate str ->
                    [ { row = row
                      , col = col
                      , problem =
                            BadDate str
                      }
                    ]

                Mark.IntOutOfRange found ->
                    [ { row = row
                      , col = col
                      , problem =
                            IntOutOfRange found
                      }
                    ]

                Mark.FloatOutOfRange found ->
                    [ { row = row
                      , col = col
                      , problem =
                            FloatOutOfRange found
                      }
                    ]

                _ ->
                    []

        last :: remaining ->
            if last.col == col && last.row == row then
                case current.problem of
                    Mark.ExpectingBlockName block ->
                        case last.problem of
                            UnknownBlock blocks ->
                                { row = row
                                , col = col
                                , problem =
                                    UnknownBlock (block :: blocks)
                                }
                                    :: remaining

                            _ ->
                                remaining

                    Mark.ExpectingInlineName block ->
                        case last.problem of
                            UnknownInline blocks ->
                                { row = row
                                , col = col
                                , problem =
                                    UnknownInline (block :: blocks)
                                }
                                    :: remaining

                            _ ->
                                remaining

                    Mark.ExpectingIndent indentation ->
                        [ { row = row
                          , col = col
                          , problem =
                                ExpectingIndent indentation
                          }
                        ]

                    _ ->
                        merged

            else
                case current.problem of
                    Mark.ExpectingBlockName block ->
                        { row = row
                        , col = col
                        , problem =
                            UnknownBlock [ block ]
                        }
                            :: merged

                    _ ->
                        merged


renderErrors : List String -> Message -> Error
renderErrors lines current =
    case current.problem of
        UnknownBlock expecting ->
            let
                line =
                    getLine current.row lines

                word =
                    getWord current line
            in
            { title = "UNKNOWN BLOCK"
            , region =
                focusWord current line
            , message =
                [ text "I don't recognize this block name.\n\n"
                , singleLine current.row (line ++ "\n")
                , highlightWord current line
                , text "Do you mean one of these instead?\n\n"
                , expecting
                    |> List.sortBy (\exp -> 0 - similarity word exp)
                    |> List.map (indent 4)
                    |> String.join "\n"
                    |> text
                    |> yellow
                ]
            }

        UnknownInline expecting ->
            let
                line =
                    getLine current.row lines
            in
            { title = "UNKNOWN INLINE"
            , region =
                focusWord current line
            , message =
                [ text "I ran into an unexpected inline name.\n\n"
                , singleLine current.row (line ++ "\n")
                , highlightUntil '|' { current | col = current.col + 1 } line
                , text "But I was expecting one of these instead:\n\n"
                , expecting
                    |> List.sortBy (\exp -> 0 - similarity line exp)
                    |> List.map (indent 4)
                    |> String.join "\n"
                    |> text
                    |> yellow
                ]
            }

        ExpectingIndent indentation ->
            let
                line =
                    getLine current.row lines
            in
            { title = "MISMATCHED INDENTATION"
            , region = focusSpace current line
            , message =
                [ text ("I was expecting " ++ String.fromInt indentation ++ " spaces of indentation.\n\n")
                , singleLine current.row (line ++ "\n")
                , highlightSpace current.col line
                ]
                    ++ hint "All indentation in `elm-markup` is a multiple of 4."
            }

        CantStartTextWithSpace ->
            let
                line =
                    getLine current.row lines
            in
            { title = "TOO MUCH SPACE"
            , region = focusSpace current line
            , message =
                [ text "This line of text starts with extra space.\n\n"
                , singleLine current.row (line ++ "\n")
                , highlightSpace (current.col - 1) line
                , text "Beyond the required indentation, text should start with non-whitespace characters."
                ]
            }

        UnclosedStyle styles ->
            let
                line =
                    getLine current.row lines
            in
            { title = "UNCLOSED STYLE"
            , region = focusSpace current line
            , message =
                [ text (styleNames styles ++ " still open.  Add " ++ String.join " and " (List.map styleChars styles) ++ " to close it.\n\n")
                , singleLine current.row (line ++ "\n")
                , text (String.join "" (List.map styleChars styles) ++ "\n")
                    |> red
                , highlightSpace current.col line
                ]
                    ++ hint "`*` is used for bold and `/` is used for italic."
            }

        UnexpectedField field ->
            let
                line =
                    getLine current.row lines

                word =
                    getPrevWord current line
            in
            { title = "UNKNOWN FIELD"
            , region =
                focusPrevWord current line
            , message =
                [ text "I ran into an unexpected field name for a "
                , text field.recordName
                    |> yellow
                , text " record\n\n"
                , singleLine current.row (line ++ "\n")
                , highlightPreviousWord current line
                , text "Do you mean one of these instead?\n\n"
                , field.options
                    |> List.sortBy (\exp -> 0 - similarity word exp)
                    |> List.map (indent 4)
                    |> String.join "\n"
                    |> text
                    |> yellow
                ]
            }

        BadDate found ->
            let
                line =
                    getLine current.row lines
            in
            { title = "BAD DATE"
            , region =
                focusWord current line
            , message =
                [ text "I was trying to parse a date, but this format looks off.\n\n"
                , singleLine current.row (line ++ "\n")
                , highlightWord current line
                , text "Dates should be in ISO 8601 format:\n\n"
                , text (indent 4 "YYYY-MM-DDTHH:mm:ss.SSSZ")
                    |> yellow
                ]
            }

        IntOutOfRange found ->
            let
                line =
                    getLine current.row lines
            in
            { title = "INTEGER OUT OF RANGE"
            , region =
                focusWord current line
            , message =
                [ text "I was expecting an "
                , yellow (text "Int")
                , text " between "
                , text (String.fromInt found.min)
                    |> yellow
                , text " and "
                , text (String.fromInt found.max)
                    |> yellow
                , text ", but found:\n\n"
                , singleLine current.row (line ++ "\n")
                , highlightWord current line
                ]
            }

        FloatOutOfRange found ->
            let
                line =
                    getLine current.row lines
            in
            { title = "FLOAT OUT OF RANGE"
            , region =
                focusWord current line
            , message =
                [ text "I was expecting a "
                , yellow (text "Float")
                , text " between "
                , text (String.fromFloat found.min)
                    |> yellow
                , text " and "
                , text (String.fromFloat found.max)
                    |> yellow
                , text ", but found:\n\n"
                , singleLine current.row (line ++ "\n")
                , highlightWord current line
                ]
            }

        NonMatchingFields fields ->
            let
                line =
                    getLine current.row lines

                remaining =
                    List.filter
                        (\f -> not <| List.member f fields.found)
                        fields.expecting
            in
            { title = "MISSING FIELD"
            , region = focusSpace current line
            , message =
                -- TODO: Highlight entire record section
                -- TODO: mention record name
                case remaining of
                    [] ->
                        -- TODO: This should never happen actually.
                        --  Maybe error should be a nonempty list?
                        [ text "It looks like a field is missing." ]

                    [ single ] ->
                        [ text "It looks like a field is missing.\n\n"
                        , text "You need to add the "
                        , yellow (text single)
                        , text " field."
                        ]

                    multiple ->
                        [ text "It looks like a field is missing.\n\n"
                        , text "You still need to add:\n"
                        , remaining
                            |> List.sortBy (\exp -> 0 - similarity line exp)
                            |> List.map (indent 4)
                            |> String.join "\n"
                            |> text
                            |> yellow
                        ]
            }


styleChars style =
    case style of
        Mark.Bold ->
            "*"

        Mark.Italic ->
            "/"

        Mark.Strike ->
            "~"


styleNames styles =
    let
        italic =
            List.any ((==) Mark.Italic) styles

        isBold =
            List.any ((==) Mark.Bold) styles

        strike =
            List.any ((==) Mark.Strike) styles
    in
    case ( italic, isBold, strike ) of
        ( False, False, False ) ->
            "Some formatting is"

        ( True, True, False ) ->
            "Italic and bold formatting are"

        ( True, True, True ) ->
            "Italic, strike, and bold formatting are"

        ( True, False, True ) ->
            "Italic and strike formatting are"

        ( False, True, True ) ->
            "Strike, and bold formatting are"

        ( True, False, False ) ->
            "Italic formatting is"

        ( False, True, False ) ->
            "Bold formatting is"

        ( False, False, True ) ->
            "Strike formatting is"


text : String -> Text
text str =
    { text = str
    , color = Nothing
    , bold = False
    , underline = False
    }


underline : Text -> Text
underline txt =
    { txt | underline = True }


bold : Text -> Text
bold txt =
    { txt | bold = True }


red : Text -> Text
red txt =
    { txt | color = Just "red" }


yellow : Text -> Text
yellow txt =
    { txt | color = Just "yellow" }


cyan : Text -> Text
cyan txt =
    { txt | color = Just "cyan" }


focusWord cursor line =
    let
        highlightLength =
            line
                |> String.dropLeft cursor.col
                |> String.words
                |> List.head
                |> Maybe.map String.length
                |> Maybe.withDefault 1
    in
    { start =
        { column = cursor.col
        , line = cursor.row
        }
    , end =
        { column = cursor.col + highlightLength
        , line = cursor.row
        }
    }


focusSpace cursor line =
    let
        start =
            String.dropLeft (cursor.col - 1) line

        trimmed =
            String.trimLeft start

        highlightLength =
            String.length start
                - String.length trimmed
                |> max 1
    in
    { start =
        { column = cursor.col
        , line = cursor.row
        }
    , end =
        { column = cursor.col + highlightLength
        , line = cursor.row
        }
    }


highlightSpace col line =
    let
        start =
            String.dropLeft (col - 1) line

        trimmed =
            String.trimLeft start

        highlightLength =
            String.length start
                - String.length trimmed
                |> max 1
    in
    red <| text (" " ++ String.repeat col " " ++ String.repeat highlightLength "^" ++ "\n")


highlightWord cursor line =
    let
        rowNumLength =
            String.length (String.fromInt cursor.row)

        highlightLength =
            line
                |> String.dropLeft (cursor.col - rowNumLength)
                |> String.words
                |> List.head
                |> Maybe.map String.length
                |> Maybe.withDefault 1
    in
    red <| text (String.repeat (rowNumLength + cursor.col - 1) " " ++ String.repeat highlightLength "^" ++ "\n")


highlightPreviousWord cursor line =
    let
        rowNumLength =
            String.length (String.fromInt cursor.row)

        start =
            String.length line - String.length (String.trimLeft line)

        highlightLength =
            line
                |> String.dropRight (String.length line - (cursor.col - 2))
                |> String.trimLeft
                |> String.length
    in
    red <| text (String.repeat (rowNumLength + start + 1) " " ++ String.repeat highlightLength "^" ++ "\n")


focusPrevWord cursor line =
    let
        start =
            String.length line - String.length (String.trimLeft line)

        highlightLength =
            line
                |> String.dropRight (String.length line - (cursor.col - 2))
                |> String.trimLeft
                |> String.length
    in
    { start =
        { column = start
        , line = cursor.row
        }
    , end =
        { column = start + highlightLength
        , line = cursor.row
        }
    }


highlightUntil end cursor line =
    let
        rowNumLength =
            String.length (String.fromInt cursor.row)

        highlightLength =
            line
                |> String.dropLeft (cursor.col - rowNumLength)
                |> String.split (String.fromChar end)
                |> List.head
                |> Maybe.map (\str -> String.length str + 1)
                |> Maybe.withDefault 1
    in
    red <| text (String.repeat (rowNumLength + cursor.col - 1) " " ++ String.repeat highlightLength "^" ++ "\n")


newline =
    { text = "\n"
    , color = Nothing
    , underline = False
    , bold = False
    }


indent x str =
    String.repeat x " " ++ str


singleLine row line =
    text <|
        String.fromInt row
            ++ (if String.startsWith "|" line then
                    ""

                else
                    "|"
               )
            ++ line


hint str =
    [ text "Hint"
        |> underline
    , text (": " ++ str)
    ]


getLine row lines =
    case List.head (List.drop (row - 1) lines) of
        Nothing ->
            "Empty"

        Just l ->
            l


getWord cursor line =
    let
        rowNumLength =
            String.length (String.fromInt cursor.row)

        highlightLength =
            line
                |> String.dropLeft (cursor.col - rowNumLength)
                |> String.words
                |> List.head
                |> Maybe.map String.length
                |> Maybe.withDefault 1

        end =
            cursor.col + highlightLength
    in
    String.slice (cursor.col - 1) end line


getPrevWord cursor line =
    let
        start =
            String.length line - String.length (String.trimLeft line)

        highlightLength =
            line
                |> String.dropRight (String.length line - (cursor.col - 2))
                |> String.trimLeft
                |> String.length
    in
    String.slice start (start + highlightLength) line