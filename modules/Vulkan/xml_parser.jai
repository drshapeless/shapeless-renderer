Node_Type :: enum {
    NODE;
    PLAIN;
}

Node :: struct {
    depth: int;
    type: Node_Type;
    // This is essensially outerHTML
    raw_string: string;

    // I think this is a good idea to have a big inner string like innerHTML
    inner_string: string;

    tag_name: string;
    attrs: [..]Attribute;
    children: [..]Node;

    parent: *Node;

    done := false;
}

parse_xml :: (s: string) -> Node {
    tokens := tokenize(s);
    node := read_tokens(tokens);

    return node;
}

find_node_of_tag_name :: (parent: Node, name: string, index: int = 0) -> *Node, int {
    if index < parent.children.count {
        for i : index..parent.children.count - 1 {
            child := *parent.children[i];
            if child.type == .NODE && child.tag_name == name {
                return child, i;
            }
        }
    }

    return null, -1;
}

get_attr :: (node: Node, key: string) -> string {
    for attr: node.attrs {
        if attr.key == key {
            return attr.value;
        }
    }

    return "";
}

is_self_close_node :: (node: Node) -> bool {
    return node.children.count == 0;
}

#scope_file

// There is only two type, tag or text.
Token_Type :: enum {
    TAG;
    TEXT;
}

Token :: struct {
    type: Token_Type;
    raw_string: string;
}

tokenize :: (s: string) -> []Token {
    pos := 0;

    tokens: [..]Token;
    while pos < s.count {
        new_pos := skip_whitespace(s, pos);

        if new_pos >= s.count {
            break;
        }

        token: Token;

        if s[new_pos] == #char "<" {
            end_pos := find_index_from_left(s, #char ">", new_pos);
            if end_pos < 0 {
                log_error("Unable to find closing angle bracket");
                break;
            }

            end_pos += 1;
            token.type = .TAG;
            token.raw_string = slice(s, new_pos, end_pos - new_pos);

            array_add(*tokens, token);
            pos = end_pos;
        } else {
            end_pos := find_index_from_left(s, #char "<", new_pos);
            if end_pos < 0 {
                break;
            }

            token.type = .TEXT;
            token.raw_string = slice(s, pos, end_pos - pos);

            array_add(*tokens, token);
            pos = end_pos;
        }
    }

    return tokens;
}

skip_whitespace :: (s: string, pos: s64 = 0) -> s64 {
    new_pos := pos;
    while new_pos < s.count && is_space(s[new_pos]) {
        new_pos += 1;
    }

    return new_pos;
}

Tag_Type :: enum {
    UNDEFINED;
    DECLARATION;
    OPEN;
    CLOSE;
    SELF_CLOSE;
    COMMENT;
}

Attribute :: struct {
    key:   string;
    value: string;
}

Tag :: struct {
    type: Tag_Type;
    name: string;
    attrs: [..]Attribute;
}

parse_tag :: (token: Token) -> Tag {
    tag: Tag;
    if token.raw_string[1] == #char "?" {
        tag.type = .DECLARATION;
        found, left := split_from_left(slice(token.raw_string, 2, token.raw_string.count - 4), #char " ");
        if found {
            tag.name = left;
        }
    } else if token.raw_string[1] == #char "!" {
        // This should be a comment
        tag.type = .COMMENT;
    } else if token.raw_string[1] == #char "/" {
        tag.type = .CLOSE;
        // A close tag should almost always contain its tag name only
        tag.name = slice(token.raw_string, 2, token.raw_string.count - 3);
    } else if token.raw_string[token.raw_string.count - 2] == #char "/" {
        tag.type = .SELF_CLOSE;
        first_space := find_index_from_left(token.raw_string, #char " ");
        if first_space < 0 {
            // It is weird to have a self close tag which contains no attrs
            tag.name = slice(token.raw_string, 1, token.raw_string.count - 3);
        } else {
            tag.name = slice(token.raw_string, 1, first_space - 1);
            // Anything beyond the first space should be an attr pair
            tag.attrs = parse_attrs(slice(token.raw_string, first_space + 1, token.raw_string.count - first_space - 2));
        }
    } else {
        tag.type = .OPEN;
        first_space := find_index_from_left(token.raw_string, #char " ");
        if first_space < 0 {
            tag.name = slice(token.raw_string, 1, token.raw_string.count - 2);
        } else {
            tag.name = slice(token.raw_string, 1, first_space - 1);
            tag.attrs = parse_attrs(slice(token.raw_string, first_space + 1, token.raw_string.count - first_space - 1));
        }
    }

    assert(tag.type != .UNDEFINED);

    return tag;
}

parse_attrs :: (s: string) -> [..]Attribute {
    attrs: [..]Attribute;

    new_pos := 0;

    while new_pos < s.count {
        new_pos = skip_whitespace(s, new_pos);
        equal_pos := find_index_from_left(s, #char "=", new_pos);
        if equal_pos < 0 {
            break;
        }

        attr: Attribute;
        attr.key = slice(s, new_pos, equal_pos - new_pos);
        first_quote_pos := find_index_from_left(s, #char "\"", new_pos);
        assert(first_quote_pos >= 0, "cannot find first quote pos in '%'", s);

        second_quote_pos := find_index_from_left(s, #char "\"", first_quote_pos + 1);
        assert(second_quote_pos >= 0, "cannot find second quote pos in '%'", s);

        attr.value = slice(s, first_quote_pos + 1, second_quote_pos - first_quote_pos - 1);
        array_add(*attrs, attr);
        new_pos = second_quote_pos + 2;
    }

    return attrs;
}

// This function parse the tokens and return a root node.
read_tokens :: (tokens: []Token) -> Node {
    root_node: Node;

    current_node: *Node = null;

    for token: tokens {
        if token.type == .TAG {
            tag := parse_tag(token);

            if tag.type == {
            case .DECLARATION;
                #through;
            case .COMMENT;
                continue;
            case .OPEN;
                if current_node != null {
                    new_node: Node;
                    new_node.type = .NODE;
                    new_node.depth = current_node.depth + 1;
                    new_node.parent = current_node;
                    new_node.raw_string = token.raw_string;
                    new_node.tag_name = tag.name;
                    new_node.attrs = tag.attrs;

                    array_add(*current_node.children, new_node);
                    current_node = *current_node.children[current_node.children.count - 1];
                } else {
                    root_node.type = .NODE;
                    root_node.raw_string = token.raw_string;
                    root_node.tag_name = tag.name;
                    root_node.attrs = tag.attrs;
                    current_node = *root_node;
                }
            case .CLOSE;
                if current_node.tag_name != tag.name {
                    log_error("Unmatch close tag, expect %, get %, raw_string %", current_node.tag_name, tag.name, token.raw_string);
                    break;
                }

                if current_node.done == true {
                    log_error("Extra close tag, raw_string %", token.raw_string);
                    break;
                }

                current_node.done = true;

                if current_node.parent == null {
                    // We are at the root node
                    break;
                }

                // compute the real raw string
                current_node.inner_string.data = current_node.raw_string.data + current_node.raw_string.count;
                current_node.inner_string.count = token.raw_string.data - current_node.inner_string.data;
                current_node.raw_string.count = token.raw_string.data + token.raw_string.count - current_node.raw_string.data;

                current_node = current_node.parent;
            case .SELF_CLOSE;
                new_node: Node;
                new_node.depth = current_node.depth + 1;
                new_node.done = true;
                new_node.type = .NODE;
                new_node.raw_string = token.raw_string;
                new_node.tag_name = tag.name;
                new_node.attrs = tag.attrs;
                new_node.parent = current_node;

                array_add(*current_node.children, new_node);
            }
        } else {
            // token is text
            new_node: Node;
            new_node.depth = current_node.depth + 1;
            new_node.done;
            new_node.type = .PLAIN;
            new_node.raw_string = token.raw_string;
            new_node.parent = current_node;

            array_add(*current_node.children, new_node);
        }
    }

    return root_node;
}

#import "Basic";
#import "String";
