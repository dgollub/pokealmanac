#!/usr/bin/env python
# encoding: utf-8
"""
    Copyright (c) 2016 by Daniel Kurashige-Gollub <daniel@kurashige-gollub.de>
    License MIT: see LICENSE file.
"""
"""
    Download the API documentation for the PokeAPI.co site, parse it and
    generate Swift structs/classes from it that allow us to easily
    use the API in an iOS project.

    WARNING: produces un-compilable code and wrong code at the moment.

    This is due to the following:
    - this code is not optimized/bug free
    - the actual API documentation on the PokeAPI.co site has actual errors,
      like listing the wrong data type
    - the actual API documentation seems to have duplicate "Version"
      definitions for the Version endpoint
    - need a way to add custom method to the result struct that resolves
      NamedAPIResourceList types into a list of the real type
    - the PokeAPI documentation lacks information about optional results
      i. e. results that can be empty/null

    TODO(dkg): also generate SQL statements and Swift methods that allow us
    to easily save and load the data gathered from the API on the device
    in a SQLite database file.
"""

import os
import codecs
# import shutil
import sys
import traceback
# fix stdout utf-8 decoding/encoding errors
reload(sys)
sys.setdefaultencoding('utf-8')
sys.stdout = codecs.getwriter('utf8')(sys.stdout)

CURRENT_PATH = os.path.dirname(os.path.abspath(__file__))
API_URL = "http://pokeapi.co/docsv2/"

if sys.version_info.major != 2 and sys.version_info.minor != 7:
    print "This script was developed with Python 2.7.x and there is no guarantee that it will work with another version."
    print "Please uncomment the version check yourself if you want to give it a try."
    sys.exit(1)

try:
    from bs4 import BeautifulSoup
except ImportError:
    print "Please install the Python library BeautifulSoup4 first."
    sys.exit(1)

try:
    import lxml
except ImportError:
    print "Please install the Python lxml library first."
    sys.exit(1)

try:
    import requests
except ImportError:
    print "Please install the Python requests library first."
    sys.exit(1)


def download_api_page():
    print "Dowloading API documentation from %s" % API_URL
    r = requests.get(API_URL)
    if r.status_code != 200:
        raise Exception("Could not download the Pokemon API site. Please check. Reason: %s" % (str(r.raw.read())))
    print "Ok"
    return unicode(r.text)


def parse_endpoint(soup, endpoint_id, already_done):
    # special cases
    # version ==> id is "versions"
    if endpoint_id == "version":
        endpoint_id = "versions"
    header = soup.find("h2", id=endpoint_id)
    if header is None:
        print "Could not find header for endpoint '%s'!!!" % (endpoint_id)
        return (None, False)
    model_header = header.find_next_sibling("h4")

    # TODO(dkg): example, url and desc are completely wrong at the moment - fix this!
    desc_element = header.find_next_sibling("p")
    if desc_element is None:
        print "No description for %s" % (endpoint_id)
        desc = ""
    else:
        desc = desc_element.text  # NOTE(dkg): text loses all inner HTML elements though ... hmmm.
    url_element = header.find_next_sibling("h3")
    url = url_element.text if url_element is not None else ""
    # example_element = header.find_next_sibling("pre")
    example = ""
    example_element = header.find_previous_sibling("pre")
    if example_element is not None:
        example_sib = example_element.find_next_sibling("h4")
        if example_sib.text == model_header.text:
            example = example_element.text if example_element is not None else ""

    # print endpoint_id, header
    # print desc
    # print url
    # print example

    code = """
//
// %(category)s - %(name)s
// %(url)s
// %(desc)s
//
%(example)s
//
//
public class %(name)s : JSONJoy {
    %(variables)s

    public required init(_ decoder: JSONDecoder) throws {
        %(trycatches)s
    }
}"""
    # TODO(dkg): what about optional variables????
    variable = "public let %(name)s: %(type)s   // %(comment)s"
    decoder_array = """
        guard let tmp%(tmpName)s = decoder["%(name)s"].array else { throw JSONError.WrongType }
        var collect%(tmpName)s = [%(type)s]()
        for tmpDecoder in tmp%(tmpName)s {
            collect%(tmpName)s.append(try %(type)s(tmpDecoder))
        }
        %(name)s = collect%(tmpName)s
"""
    decoder_type = """%(name)s = try %(type)s(decoder["%(name)s"])"""
    decoder_var = """%(name)s = try decoder["%(name)s"].%(type)s"""
    result = []

    # raise Exception("Test")

    while model_header is not None and model_header.text not in already_done:
        model_table = model_header.find_next_sibling("table")
        # print model_header
        # print model_table

        mt_body = model_table.find("tbody")
        mt_rows = mt_body.find_all("tr")

        variables = []
        trycatches = []
        for mt_row in mt_rows:
            # print mt_row
            columns = mt_row.find_all("td")
            varname = columns[0].text
            vardesc = columns[1].text
            vartype = columns[-1].text

            if vartype in ["integer", "string", "boolean"]:
                typevar = "Int" if vartype == "integer" else "String" if vartype == "string" else "Bool"
                varout = variable % {
                    "name": varname,
                    "type": typevar,
                    "comment": vardesc
                }
                decodetype = "getInt()" if vartype == "integer" else "getString()" if vartype == "string" else "bool"
                decoderout = decoder_var % {
                    "name": varname,
                    "type": decodetype
                }

            elif "list" in vartype:
                # example: list <a href="#berryflavormap">BerryFlavorMap</a>
                if "integer" in vartype:
                    typename = "[Int]"
                elif "string" in vartype:
                    typename = "[String]"
                else:
                    anchors = columns[-1].find_all("a")
                    typename = anchors[-1].text if len(anchors) > 0 else "????"
                    if len(anchors) == 0:
                        raise Exception("What is this? %s %s" % (varname, model_header.text))
                varout = variable % {
                    "name": varname,
                    "type": u"[%s]" % (typename),
                    "comment": vardesc
                }
                decoderout = decoder_array % {
                    "name": varname,
                    "type": typename,
                    "tmpName": varname.capitalize(),
                }
            elif "NamedAPIResource" in vartype:
                # TODO(dkg): Need to add additional method that converts the NamedAPIResource URL to it's correct type.
                #            Example: BerryFirmness here points to a URL, instead of the full JSON for BerryFirmness.
                #            The struct therefore should provide a method that either returns the cached data or nil
                #            if no cached data is available. (What about if the actual API didn't provide any data?)
                # example: <a href="#namedapiresource">NamedAPIResource</a> (<a href="#berry-firmnesses">BerryFirmness</a>)
                typename = columns[-1].find_all("a")[-1].text
                varout = variable % {
                    "name": varname,
                    "type": typename,
                    "comment": vardesc
                }
                decoderout = decoder_type % {
                    "name": varname,
                    "type": typename
                }
            else:
                # TODO(dkg): this case emits some wrong code for certain cases - need to fix this
                # Just handle this type as its own datatype
                varout = variable % {
                    "name": varname,
                    "type": vartype,
                    "comment": vardesc
                }
                decoderout = decoder_var % {
                    "name": varname,
                    "type": vartype
                }
                # raise Exception("Variable '%s' datatype not handled: %s" % (varname, vartype))

            variables.append(varout)
            trycatches.append(decoderout)
            # print varname, vardesc, vartype, varout
        # return

        tmp = code % {
            "category": header.text,
            "name": model_header.text.replace(" ", ""),
            "desc": desc,
            "url": url,
            "example": u"\n".join(map(lambda line: u"// %s" % line, example.split("\n"))),
            "variables": (u"\n%s" % (u" " * 4)).join(variables),
            "trycatches": (u"\n%s" % (u" " * 8)).join(trycatches),
        }
        result.append(tmp)

        already_done.append(model_header.text)

        # get the next response model
        model_header = model_header.find_next_sibling("h4")
        # print "next model_header", model_header
        # check if the next header belongs to a different endpoint
        if model_header is not None and endpoint_id not in ["common-models", "resource-lists"]:
            parent_header = model_header.find_previous_sibling("h2")
            # print 'parent_header["id"]', endpoint_id, parent_header["id"]
            if endpoint_id != parent_header["id"][1:]:
                model_header = None

    return ("\n".join(result), True)


def parse_api(api_data):
    print "Gonna parse the data now ..."

    soup = BeautifulSoup(api_data, "lxml")
    # head_element = soup.find(id="pokeapi-v2-api-reference")
    # nav_table = head_element.find_next_sibling("table")
    # lists = nav_table.find_all("ul")

    div = soup.find("div", class_="doc-select")
    lists = filter(lambda l: len(l.attrs.keys()) == 0, div.find_all("li"))

    api_endpoint_ids = []
    for l in lists:
        endpoint_id = l.a["href"]
        if endpoint_id in ["#wrap", "#info"]:
            continue
        api_endpoint_ids.append(endpoint_id)
    print api_endpoint_ids

    already_done = []
    result = []
    for endpoint in api_endpoint_ids:
        parsed_data, found = parse_endpoint(soup, endpoint[1:], already_done)  # remove # char from the id
        if found:
            result.append(parsed_data)

    return "\n".join(result)


def main():
    print "Go!"

    folder = os.path.join(CURRENT_PATH, "pokeapi.co")
    if not os.path.exists(folder):
        os.makedirs(folder)
    api_file_name = os.path.join(folder, "api.html")
    download_api = True
    ask = "dontask" not in sys.argv

    if os.path.exists(api_file_name):
        if ask:
            user_input = (raw_input("A local copy of the API site exists already. Do you want to download it anyway and overwrite the local copy? yes/[no]: ") or "").strip().lower()[:1]
            download_api = user_input in ["y", "j"]
        else:
            download_api = False

    if download_api:
        api_site_data = download_api_page()
        with codecs.open(api_file_name, "w", "utf-8") as f:
            f.write(api_site_data)
    else:
        with codecs.open(api_file_name, "r", "utf-8") as f:
            api_site_data = f.read()

    parsed_api = parse_api(api_site_data)

    if len(parsed_api) > 0:
        # print parsed_api  # TODO(dkg): write to a file
        output_file = os.path.join(folder, "pokeapi-generated.swift")
        with codecs.open(output_file, "w", "utf-8") as f:
            f.write("//\n// This file was generated by a Python script.\n// DO NOT USE THIS CODE DIRECTLY! IT DOES NOT COMPILE!\n//\n\n")
            f.write("//\n// There are documentation errors in the API, so some types are wrong.\n// Double check everything before ")
            f.write("using any of this generated code.\n// DO NOT USE THIS CODE DIRECTLY! IT DOES NOT COMPILE!\n//\n\n")
            f.write(parsed_api)
            f.write("\n")

        print "Wrote %s" % (output_file)
    print "Done."

try:
    main()
except Exception as ex:
    print "Something went wrong. Oops."
    print ex
    traceback.print_exc(file=sys.stdout)
