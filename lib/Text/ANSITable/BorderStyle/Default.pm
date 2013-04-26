package Text::ANSITable::BorderStyle::Default;

use 5.010;
use strict;
use utf8;
use warnings;

# VERSION

our %border_styles = (

    # none

    none => {
        summary => 'No border',
        chars => [
            ['','','',''],
            [' ',' ',' '],
            ['','','',''],
            [' ',' ',' '],
            ['','','',''],
            ['','','',''],
        ],
    },

    # space
    space => {
        summary => 'Space as border',
        chars => [
            [' ',' ',' ',' '],
            [' ',' ',' '],
            [' ',' ',' ',' '],
            [' ',' ',' '],
            [' ',' ',' ',' '],
            [' ',' ',' ',' '],
        ],
    },


    # single

    single_ascii => {
        summary => 'Single',
        chars => [
            ['.','-','+','.'],
            ['|','|','|'],
            ['+','-','+','|'],
            ['|','|','|'],
            ['+','-','+','|'],
            ['`','-','+',"'"],
        ],
    },

    single_boxchar => {
        summary => 'Single',
        chars => [
            ['l','q','w','k'],
            ['x','x','x'],
            ['t','q','n','u'],
            ['x','x','x'],
            ['t','q','n','u'],
            ['m','q','v','j'],
        ],
        box_chars => 1,
    },

    single_utf8 => {
        summary => 'Single',
        chars => [
            ["┌","─","┬","┐"],
            ["│","│","│"],
            ["├","─","┼","┤"],
            ["│","│","│"],
            ["├","─","┼","┤"],
            ["└","─","┴","┘"],
        ],
        utf8 => 1,
    },


    # single, horizontal only

    singleh_ascii => {
        summary => 'Single, horizontal only',
        chars => [
            ['-','-','-','-'],
            [' ',' ',' '],
            ['-','-','-','-'],
            [' ',' ',' '],
            ['-','-','-','-'],
            ['-','-','-','-'],
        ],
    },

    singleh_boxchar => {
        summary => 'Single, horizontal only',
        chars => [
            ['q','q','q','q'],
            [' ',' ',' '],
            ['q','q','q','q'],
            [' ',' ',' '],
            ['q','q','q','q'],
            ['q','q','q','q'],
        ],
        box_chars => 1,
    },

    singleh_utf8 => {
        summary => 'Single, horizontal only',
        chars => [
            ['─','─','─','─'],
            [' ',' ',' '],
            ['─','─','─','─'],
            [' ',' ',' '],
            ['─','─','─','─'],
            ['─','─','─','─'],
        ],
        utf8 => 1,
    },


    # single, vertical only

    singlev_ascii => {
        summary => 'Single border, only vertical',
        chars => [
            ['|',' ','|','|'],
            ['|','|','|'],
            ['|',' ','|','|'],
            ['|','|','|'],
            ['|',' ','|','|'],
            ['|',' ','|','|'],
        ],
    },

    singlev_boxchar => {
        summary => 'Single, vertical only',
        chars => [
            ['x',' ','x','x'],
            ['x','x','x'],
            ['x',' ','x','x'],
            ['x','x','x'],
            ['x',' ','x','x'],
            ['x',' ','x','x'],
        ],
        box_chars => 1,
    },

    singlev_boxchar => {
        summary => 'Single, vertical only',
        chars => [
            ['│',' ','│','│'],
            ['│','│','│'],
            ['│',' ','│','│'],
            ['│','│','│'],
            ['│',' ','│','│'],
            ['│',' ','│','│'],
        ],
        utf8 => 1,
    },


    # single, inner only

    singlei_ascii => {
        summary => 'Single, inner only (like in psql command-line client)',
        chars => [
            ['','','',''],
            [' ','|',' '],
            [' ','-','+',' '],
            [' ','|',' '],
            [' ','-','+',' '],
            ['','','',''],
        ],
    },

    singlei_boxchar => {
        summary => 'Single, inner only (like in psql command-line client)',
        chars => [
            ['','','',''],
            [' ','x',' '],
            [' ','q','n',' '],
            [' ','x',' '],
            [' ','q','n',' '],
            ['','','',''],
        ],
        box_chars => 1,
    },

    singlei_utf8 => {
        summary => 'Single, inner only (like in psql command-line client)',
        chars => [
            ["","","",""],
            [" ","│"," "],
            [" ","─","┼"," "],
            [" ","│"," "],
            [" ","─","┼"," "],
            ["","","",""],
        ],
        utf8 => 1,
    },


    # single, outer only

    singleo_ascii => {
        summary => 'Single, outer only',
        chars => [
            ['.','-','-','.'],
            ['|',' ','|'],
            ['|',' ',' ','|'],
            ['|',' ','|'],
            ['|',' ',' ','|'],
            ['`','-','-',"'"],
        ],
    },

    singleo_boxchar => {
        summary => 'Single, outer only',
        chars => [
            ['l','q','q','k'],
            ['x',' ','x'],
            ['x',' ',' ','x'],
            ['x',' ','x'],
            ['x',' ',' ','x'],
            ['m','q','q','j'],
        ],
        box_chars => 1,
    },

    singleo_utf8 => {
        summary => 'Single, outer only',
        chars => [
            ["┌","─","─","┐"],
            ["│"," ","│"],
            ["│"," "," ","│"],
            ["│"," ","│"],
            ["│"," "," ","│"],
            ["└","─","─","┘"],
        ],
        utf8 => 1,
    },


    # curved single

    csingle => {
        summary => 'Curved single',
        chars => [
            ["╭","─","┬","╮"],
            ["│","│","│"],
            ["├","─","┼","┤"],
            ["│","│","│"],
            ["├","─","┼","┤"],
            ["╰","─","┴","╯"],
        ],
        utf8 => 1,
    },


    # bold single

    bold => {
        summary => 'Bold',
        chars => [
            ["┏","━","┳","┓"],
            ["┃","┃","┃"],
            ["┣","━","╋","┫"],
            ["┃","┃","┃"],
            ["┣","━","╋","┫"],
            ["┗","━","┻","┛"],
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
            ["╔","═","╦","╗"],
            ["║","║","║"],
            ["╠","═","╬","╣"],
            ["║","║","║"],
            ["╠","═","╬","╣"],
            ["╚","═","╩","╝"],
        ],
        utf8 => 1,
    },

    brick => {
        summary => 'Single, bold on bottom right to give illusion of depth',
        chars => [
            ["┌","─","┬","┒"],
            ["│","│","┃"],
            ["├","─","┼","┨"],
            ["│","│","┃"],
            ["├","─","┼","┨"],
            ["┕","━","┷","┛"],
        ],
        utf8 => 1,
    },

    bricko => {
        summary => 'Single, outer only, '.
            'bold on bottom right to give illusion of depth',
        chars => [
            ["┌","─","─","┒"],
            ["│"," ","┃"],
            ["│"," "," ","┃"],
            ["│"," ","┃"],
            ["│"," "," ","┃"],
            ["┕","━","━","┛"],
        ],
    },

);

1;
# ABSTRACT: Default border styles

