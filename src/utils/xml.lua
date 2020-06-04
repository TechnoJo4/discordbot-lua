local mod = { id = "xml", g = {"xml_parse"} }

-- parsing loosely based on:
-- https://github.com/jonathanpoelen/xmlparser

local S, C, R, P = lpeg.S, lpeg.C, lpeg.R, lpeg.P
local Ct, Cg, Cf, Cs = lpeg.Ct, lpeg.Cg, lpeg.Cf, lpeg.Cs
local I, Ce = lpeg.Cp(), lpeg.Cc()

-- rules
local Space = S" \n\t"
local Space0 = Space^0
local Space1 = Space^1
local  String = (S"'" *   (1-S"'")^0  * S"'") + (S'"' *   (1-S'"')^0  * S'"')
local CString = (S"'" * C((1-S"'")^0) * S"'") + (S'"' * C((1-S'"')^0) * S'"')
local  Name = ((R("az","AZ") + S"_") * (R("az","AZ") + S"_-:" + R"09")^0)
local CName = C(Name)
local  Attr =   ( Name * Space0 * "=" * Space0 *  String )
local CAttr = Cg(CName * Space0 * "=" * Space0 * CString)
local  Comment = "<!--" *  (1-P"-->")^0 * "-->"
local CComment = "<!--" * C(1-P"-->")^0 * "-->"
local  Entity =   ("<!ENTITY" * Space1 *  Name * Space1 *  String * Space0 * ">")
local CEntity = Cg("<!ENTITY" * Space1 * CName * Space1 * CString * Space0 * ">")

local Attrs = (Space1 *  Attr)^0 * Space0
local Comments = Space0 * (Comment * Space0)^0
local CAttrs = Cf(Ct"" * (Space1 * CAttr)^0, rawset) * Space0

function mod.parser()
    -- used by functions
    local elem, doc

    -- more rules
    local Preproc = (Comments * (("<?" * CName * CAttrs * "?>") /
            function(name, attrs)
                doc.preprocessor[#doc.preprocessor+1] = {tag=name, attrs=attrs}
            end))^0
    
    local Entities = (Comments * (Cg(CEntity) /
            function(k, v)
                doc.entities[#doc.entities+1] = {name=k, value=v}
            end))^0

    local Doctype = Comments * ("<!DOCTYPE" * Space1 * Name * Space1 * (R"AZ"^1) * Space1 * String * Space0 * (P">" + "[" * Entities * Comments * "]>"))^-1

    local Tag = "<" * (CName * CAttrs /
            function(name, attrs)
                elem.children[#elem.children+1] = {tag=name, attrs=attrs, parent=elem, children={}}
            end)
    local Open = P">" * (Ce / function() elem = elem.children[#elem.children] end) + "/>"
    local Close = "</" * (CName / function() elem = elem.parent end) * Space0 * ">"

    local Text = C((Space0 * (1-S" \n\t<")^1)^1) /
            function(pos, text)
                elem.children[#elem.children+1] = {parent=elem, text=text, pos=pos}
            end
    local Cdata = "<![CDATA[" * (C((1 - P"]]>")^0) * "]]>" /
            function(pos, text)
                elem.children[#elem.children+1] = {parent=elem, text=text, cdata=true, pos=pos-9}
            end)

    local G = Preproc * Doctype * (Space0 * (Tag * Open + Close + Comment + Cdata + Text))^0 * Space0 * I

    return function(str)
        local perr
        do -- initialization
            elem = { children = {}, bad = { children = {} } }
            doc = { preprocessor = {}, entities = {}, document=elem }
            elem.parent = bad
            elem.bad.parent = elem.bad
        end

        local pos = G:match(str)
        if pos < #str then
            perr = "parse error at position " .. tostring(pos)
        end

        do -- epilogue
            if doc.document ~= elem then
                err = (err and err .. ' ' or '') .. 'No matching close for ' .. tostring(elem.tag) .. ' at position ' .. tostring(elem.pos)
            end
            doc.bad = doc.document.bad
            doc.bad.parent = nil
            doc.document.bad = nil
            doc.document.parent = nil
            doc.children = doc.document.children
            doc.document = nil
            if 0 == #doc.bad.children then
                doc.bad = nil
            else
                err = (err and err .. ' ' or '') .. 'No matching open for ' .. tostring(doc.bad.children[1].tag) .. ' at position ' .. tostring(doc.bad.children[1].pos)
            end
            doc.lastpos = pos
            if err then
                doc.error = err
            end
        end
        return doc, perr or err
    end
end

mod.parse = mod.parser()
mod.xml_parse = mod.parse

return mod