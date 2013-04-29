package Text::ANSITable::BorderStyle::Default;

use 5.010;
use strict;
use utf8;
use warnings;

# VERSION

our %border_styles = (

    # none

    none_ascii => {
        summary => 'No border',
        chars => [
            ['','','',''],     # 0
            ['','',''],        # 1
            ['','','',''],     # 2
            ['','',''],        # 3
            [' ','-','-',' '], # 4
            ['','','',''],     # 5
        ],
    },

    none_boxchar => {
        summary => 'No border',
        chars => [
            ['','','',''],     # 0
            ['','',''],        # 1
            ['','','',''],     # 2
            ['','',''],        # 3
            ['','q','q',''],   # 4
            ['','','',''],     # 5
        ],
        box_chars => 1,
    },

    none_utf8 => {
        summary => 'No border',
        chars => [
            ['','','',''],     # 0
            ['','',''],        # 1
            ['','','',''],     # 2
            ['','',''],        # 3
            ['','─','─',''],   # 4
            ['','','',''],     # 5
        ],
        utf8 => 1,
    },


    # space

    space_ascii => {
        summary => 'Space as border',
        chars => [
            [' ',' ',' ',' '], # 0
            [' ',' ',' '],     # 1
            [' ',' ',' ',' '], # 2
            [' ',' ',' '],     # 3
            [' ','-','-',' '], # 4
            [' ',' ',' ',' '], # 5
        ],
    },

    space_boxchar => {
        summary => 'Space as border',
        chars => [
            [' ',' ',' ',' '], # 0
            [' ',' ',' '],     # 1
            [' ',' ',' ',' '], # 2
            [' ',' ',' '],     # 3
            [' ','q','q',' '], # 4
            [' ',' ',' ',' '], # 5
        ],
        box_chars => 1,
    },

    space_utf8 => {
        summary => 'Space as border',
        chars => [
            [' ',' ',' ',' '], # 0
            [' ',' ',' '],     # 1
            [' ',' ',' ',' '], # 2
            [' ',' ',' '],     # 3
            [' ','─','─',' '], # 4
            [' ',' ',' ',' '], # 5
        ],
        utf8 => 1,
    },


    # single

    single_ascii => {
        summary => 'Single',
        chars => [
            ['.','-','+','.'], # 0
            ['|','|','|'],     # 1
            ['+','-','+','|'], # 2
            ['|','|','|'],     # 3
            ['+','-','+','|'], # 4
            ['`','-','+',"'"], # 5
        ],
    },

    single_boxchar => {
        summary => 'Single',
        chars => [
            ['l','q','w','k'], # 0
            ['x','x','x'],     # 1
            ['t','q','n','u'], # 2
            ['x','x','x'],     # 3
            ['t','q','n','u'], # 4
            ['m','q','v','j'], # 5
        ],
        box_chars => 1,
    },

    single_utf8 => {
        summary => 'Single',
        chars => [
            ['┌','─','┬','┐'], # 0
            ['│','│','│'],     # 1
            ['├','─','┼','┤'], # 2
            ['│','│','│'],     # 3
            ['├','─','┼','┤'], # 4
            ['└','─','┴','┘'], # 5
        ],
        utf8 => 1,
    },


    # single, horizontal only

    singleh_ascii => {
        summary => 'Single, horizontal only',
        chars => [
            ['-','-','-','-'], # 0
            [' ',' ',' '],     # 1
            ['-','-','-','-'], # 2
            [' ',' ',' '],     # 3
            ['-','-','-','-'], # 4
            ['-','-','-','-'], # 5
        ],
    },

    singleh_boxchar => {
        summary => 'Single, horizontal only',
        chars => [
            ['q','q','q','q'], # 0
            [' ',' ',' '],     # 1
            ['q','q','q','q'], # 2
            [' ',' ',' '],     # 3
            ['q','q','q','q'], # 4
            ['q','q','q','q'], # 5
        ],
        box_chars => 1,
    },

    singleh_utf8 => {
        summary => 'Single, horizontal only',
        chars => [
            ['─','─','─','─'], # 0
            [' ',' ',' '],     # 1
            ['─','─','─','─'], # 2
            [' ',' ',' '],     # 3
            ['─','─','─','─'], # 4
            ['─','─','─','─'], # 5
        ],
        utf8 => 1,
    },


    # single, vertical only

    singlev_ascii => {
        summary => 'Single border, only vertical',
        chars => [
            ['|',' ','|','|'], # 0
            ['|','|','|'],     # 1
            ['|',' ','|','|'], # 2
            ['|','|','|'],     # 3
            ['|','-','|','|'], # 4
            ['|',' ','|','|'], # 5
        ],
    },

    singlev_boxchar => {
        summary => 'Single, vertical only',
        chars => [
            ['x',' ','x','x'], # 0
            ['x','x','x'],     # 1
            ['x',' ','x','x'], # 2
            ['x','x','x'],     # 3
            ['x','q','x','x'], # 4
            ['x',' ','x','x'], # 5
        ],
        box_chars => 1,
    },

    singlev_utf8 => {
        summary => 'Single, vertical only',
        chars => [
            ['│',' ','│','│'], # 0
            ['│','│','│'],     # 1
            ['│',' ','│','│'], # 2
            ['│','│','│'],     # 3
            ['│','─','│','│'], # 4
            ['│',' ','│','│'], # 5
        ],
        utf8 => 1,
    },


    # single, inner only

    singlei_ascii => {
        summary => 'Single, inner only (like in psql command-line client)',
        chars => [
            ['','','',''],     # 0
            [' ','|',' '],     # 1
            [' ','-','+',' '], # 2
            [' ','|',' '],     # 3
            [' ','-','+',' '], # 4
            ['','','',''],     # 5
        ],
    },

    singlei_boxchar => {
        summary => 'Single, inner only (like in psql command-line client)',
        chars => [
            ['','','',''],     # 0
            [' ','x',' '],     # 1
            [' ','q','n',' '], # 2
            [' ','x',' '],     # 3
            [' ','q','n',' '], # 4
            ['','','',''],     # 5
        ],
        box_chars => 1,
    },

    singlei_utf8 => {
        summary => 'Single, inner only (like in psql command-line client)',
        chars => [
            ['','','',''],     # 0
            [' ','│',' '],     # 1
            [' ','─','┼',' '], # 2
            [' ','│',' '],     # 3
            [' ','─','┼',' '], # 4
            ['','','',''],     # 5
        ],
        utf8 => 1,
    },


    # single, outer only

    singleo_ascii => {
        summary => 'Single, outer only',
        chars => [
            ['.','-','-','.'], # 0
            ['|',' ','|'],     # 1
            ['|',' ',' ','|'], # 2
            ['|',' ','|'],     # 3
            ['+','-','-','+'], # 4
            ['`','-','-',"'"], # 5
        ],
    },

    singleo_boxchar => {
        summary => 'Single, outer only',
        chars => [
            ['l','q','q','k'], # 0
            ['x',' ','x'],     # 1
            ['x',' ',' ','x'], # 2
            ['x',' ','x'],     # 3
            ['t','q','q','u'], # 4
            ['m','q','q','j'], # 5
        ],
        box_chars => 1,
    },

    singleo_utf8 => {
        summary => 'Single, outer only',
        chars => [
            ['┌','─','─','┐'], # 0
            ['│',' ','│'],     # 1
            ['│',' ',' ','│'], # 2
            ['│',' ','│'],     # 3
            ['├','─','─','┤'], # 4
            ['└','─','─','┘'], # 5
        ],
        utf8 => 1,
    },


    # curved single

    csingle => {
        summary => 'Curved single',
        chars => [
            ['╭','─','┬','╮'], # 0
            ['│','│','│'],     # 1
            ['├','─','┼','┤'], # 2
            ['│','│','│'],     # 3
            ['├','─','┼','┤'], # 4
            ['╰','─','┴','╯'], # 5
        ],
        utf8 => 1,
    },


    # bold single

    bold => {
        summary => 'Bold',
        chars => [
            ['┏','━','┳','┓'], # 0
            ['┃','┃','┃'],     # 1
            ['┣','━','╋','┫'], # 2
            ['┃','┃','┃'],     # 3
            ['┣','━','╋','┫'], # 4
            ['┗','━','┻','┛'], # 5
        ],
        utf8 => 1,
    },


    #vbold => {
    #    summary => 'Vertically-bold',
    #},


    #hbold => {
    #    summary => 'Horizontally-bold',
    #},


    # double

    double => {
        summary => 'Double',
        chars => [
            ['╔','═','╦','╗'], # 0
            ['║','║','║'],     # 1
            ['╠','═','╬','╣'], # 2
            ['║','║','║'],     # 3
            ['╠','═','╬','╣'], # 4
            ['╚','═','╩','╝'], # 5
        ],
        utf8 => 1,
    },


    # brick

    brick => {
        summary => 'Single, bold on bottom right to give illusion of depth',
        chars => [
            ['┌','─','┬','┒'], # 0
            ['│','│','┃'],     # 1
            ['├','─','┼','┨'], # 2
            ['│','│','┃'],     # 3
            ['├','─','┼','┨'], # 4
            ['┕','━','┷','┛'], # 5
        ],
        utf8 => 1,
    },

    bricko => {
        summary => 'Single, outer only, '.
            'bold on bottom right to give illusion of depth',
        chars => [
            ['┌','─','─','┒'], # 0
            ['│',' ','┃'],     # 1
            ['│',' ',' ','┃'], # 2
            ['│',' ','┃'],     # 3
            ['├','─','─','┨'], # 4
            ['┕','━','━','┛'], # 5
        ],
        utf8 => 1,
    },

);

1;
# ABSTRACT: Default border styles

