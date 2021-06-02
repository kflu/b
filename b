#!/usr/bin/env python3

""" Generate directory listing to index.html recursively for the top directory
given in commandline argument.

Hidden files and directories are not included in the listing. The resulting
directory listings are sorted and listed. For sorting:

    1. directories first, then files
    2. then sort by names

The directory listings are written to index.html with footer and headers. The
footer and headers are specified in that directory's `.brc` file, which is a
Python file that should define following variables:

    - HEADER: a string representing the content to show before the listing
    - FOOTER: a string representing the content to show after the listing

Note that index.html are wrapped in a <pre> tag.

Finally, it changes directory mode:
    1. by default all have go=rX
    2. this tool is go-rwx
    3. all .brc files are go-rwx
"""

import datetime as dt
import os
import stat
import subprocess as sp
import sys

BRC = ".brc"
INDEX = f"index.html"


def _P(x):
    """Print and return. Used for debugging"""
    #print(x)
    return x


def listdir(d):
    __ = os.listdir(d)
    # Below two lines sort by dir THEN name (stable sort)
    __ = sorted(__, key=lambda x: x)
    __ = sorted(__, key=lambda x: 0 if os.path.isdir(x) else 1)
    __ = [x for x in __ if include_item(x)]
    __ = [f"{x}/" if os.path.isdir(x) else x for x in __]
    return __


def gen_render_index(items):

    for x in items:
        dtstr = (dt.datetime
                   .fromtimestamp(os.stat(x).st_mtime)
                   .isoformat())

        if x != "index.html":
            link = f"<a href=\"{x}\">{x}</a>"
            # Figure out right padding. If name too long, then we pad 4 spaces
            pad = 25 - len(x)
            pad = 40 - len(x) if pad < 0 else pad
            pad = 4           if pad < 0 else pad
            line = f"{link}{' '*pad}{dtstr}"
            yield line


def make_index(d):
    """Recursively make index.html starting at
    directory d"""
    pwd = os.getcwd()
    os.chdir(d)
    try:

        # read directory config
        config={"HEADER":"", "FOOTER":""}
        if os.path.exists(BRC):
            try:
                exec(open(BRC, "r").read(), {}, config)
            except Exception as e:
                print(f"Error executing {BRC}: {e}")

        try:
            os.remove(INDEX)
        except:
            pass

        lines = [
            "<pre>",
            config["HEADER"],
            *gen_render_index(listdir(".")),
            config["FOOTER"],
            "</pre>",
        ]

        print(
            "\n".join(lines),
            file=open(INDEX, "w")
        )

        for child in [x for x in os.listdir(".")
                      if os.path.isdir(x)]:
            make_index(child)
    finally:
        os.chdir(pwd)


def item_is_bit_set(item, bit):
    mode = os.stat(item).st_mode
    return (mode & bit) != 0


def item_is_other_r_set(item):
    return item_is_bit_set(item, 0o004)


def item_is_other_x_set(item):
    return item_is_bit_set(item, 0o001)


def include_item_on_mode(item):
    if os.path.isdir(item):
        return item_is_other_x_set(item)
    else:
        return item_is_other_r_set(item)


def include_item_non_hidden(item):
    return not os.path.basename(item).startswith(".")


def include_item(item):
    return all([f(item) for f in [
        # include_item_on_mode,
        include_item_non_hidden
    ]])


def chmod(d, this_tool):
    # it's supposed to set directory to go=x, but without `r`, tilde.town
    # seems to not redirect tilde.town/~user into tilde.town/~user/, resulting
    # in a 404 error. So, switching it back to go=rx. THIS MEANS, LOCAL USERS
    # CAN LIST THE DIRECTORY CONTENT:
    # sp.check_call(f"find {d} -type d -print0 | xargs -0 chmod go=x", shell=True)
    sp.check_call(f"find {d} -type d -print0 | xargs -0 chmod go=rx", shell=True)
    sp.check_call(f"find {d} -type f -print0 | xargs -0 chmod go=r", shell=True)
    sp.check_call(f"chmod go-rwx \"{this_tool}\"", shell=True)
    sp.check_call(
        _P(f"find {d} -type f -name \"{BRC}\" -print0 | xargs -0 chmod go-rwx"),
        shell=True
    )


if __name__ == "__main__":
    curdir = sys.argv[1] if len(sys.argv) > 1 else "."
    make_index(curdir)
    chmod(curdir, sys.argv[0])


# vim: set ft=python tw=80 cc=80
