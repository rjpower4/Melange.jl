"""
    SpiceText

Functionality for reading spice text kernels.
"""
module SpiceText

struct Token
    kind::Symbol
    lexeme::String
end

mutable struct Lexer
    input::String
    position::Int
    read_position::Int
    char::Char
end

function Lexer(input::String)
    lex = Lexer(input, 1, 1, '\0')
    advance!(lex)
    return lex
end

function peek(lex::Lexer)
    valid = lex.read_position <= length(lex.input)
    c = valid ? lex.input[lex.read_position] : '\0'
    return c
end

function advance!(lex::Lexer)
    valid = lex.read_position <= length(lex.input)
    lex.char = valid ? lex.input[lex.read_position] : '\0'
    lex.position = lex.read_position
    lex.read_position += 1
    return nothing
end

function eat_whitespace!(lex::Lexer)
    while lex.char in " \t"
        advance!(lex)
    end
end

function read_number!(lex::Lexer)
    start = lex.position
    state = :start

    while true
        if state == :start
            if isdigit(lex.char)
                advance!(lex)
                state = :before_point
            elseif lex.char == '.'
                advance!(lex)
                state = :after_point
            elseif lex.char in "+-"
                advance!(lex)
            else
                break
            end
        elseif state == :before_point
            if isdigit(lex.char)
                advance!(lex)
            elseif lex.char in "eEdD"
                state = :after_point
            elseif lex.char == '.'
                advance!(lex)
                state = :after_point
            else
                break
            end
        elseif state == :after_point
            if isdigit(lex.char)
                advance!(lex)
            elseif lex.char in "eEdD"
                c = peek(lex)
                if c in "+-"
                    advance!(lex)
                    advance!(lex)
                end
                state = :after_sci
            else
                break
            end
        elseif state == :after_sci
            if isdigit(lex.char)
                advance!(lex)
            else
                break
            end
        end
    end
    return lex.input[start:(lex.position-1)]
end

function read_identifier!(lex::Lexer)
    start = lex.position
    isletter(lex.char) || error("invalid identifier start")
    advance!(lex)
    while !(lex.char in " ()=\t\0")
        advance!(lex)
    end
    return lex.input[start:(lex.position-1)]
end

function read_date!(lex::Lexer)
    lex.char == '@' || error("invalid date start")
    advance!(lex)
    start = lex.position
    advance!(lex)
    while !(lex.char in " {}';,()=\t\0")
        advance!(lex)
    end
    return lex.input[start:(lex.position-1)]
end

function read_string!(lex::Lexer)
    lex.char == '\'' || error("invalid string literal start")
    advance!(lex)
    io = IOBuffer()
    while true
        if lex.char == '\''
            if peek(lex) == '\''
                advance!(lex)
                write(io, '\'')
            else
                break
            end
        else
            write(io, lex.char)
        end
        advance!(lex)
    end
    advance!(lex)
    return String(take!(io))
end

function next!(lex::Lexer)
    eat_whitespace!(lex)
    if lex.char == '='
        p = peek(lex)
        tok = if p == '='
            advance!(lex)
            (:equal, "==")
        else
            (:assign, "=")
        end
        advance!(lex)
        return tok
    elseif lex.char == '+'
        p = peek(lex)
        tok = if p == '='
            advance!(lex)
            (:plus_assign, "+=")
        elseif isdigit(p) || p == '.'
            lit = read_number!(lex)
            return (:number, lit)
        else
            (:plus, "+")
        end
        advance!(lex)
        return tok
    elseif lex.char == '-'
        p = peek(lex)
        tok = if isdigit(p) || p == '.'
            lit = read_number!(lex)
            (:number, lit)
        else
            advance!(lex)
            (:minus, "-")
        end
        return tok
    elseif lex.char == '\n'
        advance!(lex)
        return (:newline, "\n")
    elseif lex.char == '\r'
        p = peek(lex)
        tok = if p == '\n'
            advance!(lex)
            (:newline, "\r\n")
        else
            error("sole carriage return")
        end
        advance!(lex)
        return tok
    elseif lex.char == '('
        advance!(lex)
        return (:lparen, "(")
    elseif lex.char == ')'
        advance!(lex)
        return (:rparen, ")")
    elseif lex.char == '{'
        advance!(lex)
        return (:lbrace, "{")
    elseif lex.char == '}'
        advance!(lex)
        return (:rbrace, "}")
    elseif lex.char == ','
        advance!(lex)
        return (:comma, ",")
    elseif lex.char == ';'
        advance!(lex)
        return (:semicolon, ";")
    elseif lex.char == '\0'
        advance!(lex)
        return (:eof, "\0")
    elseif lex.char == '\''
        lit = read_string!(lex)
        return (:string, lit)
    elseif lex.char == '@'
        lit = read_date!(lex)
        return (:date, lit)
    elseif isletter(lex.char)
        ident = read_identifier!(lex)
        return (:identifier, ident)
    elseif isdigit(lex.char) || lex.char == '.'
        num = read_number!(lex)
        return (:number, num)
    end

    t = (:invalid, lex.char |> string)
    advance!(lex)
    return t
end

function tokens(block::String)
    lexer = Lexer(block)
    tokens = [next!(lexer)]
    while tokens[end][1] != :eof
        push!(tokens, next!(lexer))
    end
    return tokens
end

mutable struct Parser
    tokens::Vector{Tuple{Symbol,String}}
    token::Tuple{Symbol,String}
    position::Int
    read_position::Int
end

function Parser(s::String)
    tks = tokens(s)
    p = Parser(tks, (:eof, "EOF"), 1, 1)
    advance!(p)
    return p
end

function eat_whitespace!(parser::Parser)
    count = 0
    while parser.token[1] == :newline
        advance!(parser)
        count += 1
    end
    return count
end

function peek(parser::Parser)
    valid = parser.read_position <= length(parser.tokens)
    c = valid ? parser.tokens[parser.read_position] : (:eof, "EOF")
    return c
end

function advance!(parser::Parser)
    valid = parser.read_position <= length(parser.tokens)
    p = parser.token
    parser.token = valid ? parser.tokens[parser.read_position] : (:eof, "EOF")
    parser.position = parser.read_position
    parser.read_position += 1
    return p
end

function parse_rexpr!(parser::Parser)
    eat_whitespace!(parser)
    if parser.token[1] == :lparen
        advance!(parser)
        tks = Vector{typeof(parser.token)}()

        while parser.token[1] != :rparen
            t = advance!(parser)
            if t[1] in (:number, :string, :date)
                push!(tks, t)
            end
        end
        advance!(parser)


        return tks
    else
        return [advance!(parser)]
    end
end

struct Assignment
    op::Tuple{Symbol,String}
    left::Tuple{Symbol,String}
    right::Vector{Tuple{Symbol,String}}
end

function parse_assignment!(parser::Parser)
    eat_whitespace!(parser)
    if parser.token[1] != :identifier
        @show parser.token
        error("expected identifier")
    end

    id = advance!(parser)

    if !(parser.token[1] in (:assign, :plus_assign))
        error("expected assignment")
    end
    op = advance!(parser)

    as = Assignment(op, id, parse_rexpr!(parser))

    n = eat_whitespace!(parser)
    n >= 1 || error("expected newline")
    return as
end

function parse_data_block(s::String)
    parser = Parser(s)
    assignments = Vector{Assignment}()

    eat_whitespace!(parser)
    while parser.token[1] != :eof
        push!(assignments, parse_assignment!(parser))
    end
    return assignments
end


function parse(s::String)
    io = IOBuffer(s)
    comments = Vector{String}()
    assignments = Vector{Assignment}()
    id_word = readline(io) |> strip
    state = :text

    buf = IOBuffer()

    for line in eachline(io, keep=true)
        if state == :text
            if strip(line) == "\\begindata"
                push!(comments, String(take!(buf)))
                state = :data
            else
                write(buf, line)
            end
        elseif state == :data
            if strip(line) == "\\begintext"
                s = String(take!(buf))
                append!(assignments, parse_data_block(s))
                state = :text
            else
                write(buf, line)
            end
        else
            error("invalid parse state...?")
        end
    end


    return (id_word, comments, assignments)
end


end
