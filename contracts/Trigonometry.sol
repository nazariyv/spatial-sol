/**
 * Basic trigonometry functions
 *
 * Solidity library offering the functionality of basic trigonometry functions
 * with both input and output being integer approximated.
 *
 * This is useful since:
 * - At the moment no floating/fixed point math can happen in solidity
 * - Should be (?) cheaper than the actual operations using floating point
 *   if and when they are implemented.
 *
 * The implementation is based off Dave Dribin's trigint C library
 * http://www.dribin.org/dave/trigint/
 * Which in turn is based from a now deleted article which can be found in
 * the internet wayback machine:
 * http://web.archive.org/web/20120301144605/http://www.dattalo.com/technical/software/pic/picsine.html
 *
 * Original @author Lefteris Karapetsas
 * Updates @author Astral 2021
 * @license BSD3
 */

// SPDX-License-Identifier: BSD3

pragma solidity ^0.7.0;


library Trigonometry {

    // Table index into the trigonometric table
    uint256 public constant INDEX_WIDTH = 4;
    // Interpolation between successive entries in the tables
    uint256 public constant INTERP_WIDTH = 8;
    uint256 public constant INDEX_OFFSET = 12 - INDEX_WIDTH;
    uint256 public constant INTERP_OFFSET = INDEX_OFFSET - INTERP_WIDTH;
    uint16 public constant ANGLES_IN_CYCLE = 16384;
    uint16 public constant QUADRANT_HIGH_MASK = 8192;
    uint16 public constant QUADRANT_LOW_MASK = 4096;
    uint256 public constant SINE_TABLE_SIZE = 16;

    // constant sine lookup table generated by gen_tables.py
    // We have no other choice but this since constant arrays don't yet exist
    uint8 public constant entry_bytes = 2;
    bytes public constant sin_table = "\x00\x00\x0c\x8c\x18\xf9\x25\x28\x30\xfb\x3c\x56\x47\x1c\x51\x33\x5a\x82\x62\xf1\x6a\x6d\x70\xe2\x76\x41\x7a\x7c\x7d\x89\x7f\x61\x7f\xff";

    /**
     * Convenience function to apply a mask on an integer to extract a certain
     * number of bits. Using exponents since solidity still does not support
     * shifting.
     *
     * @param _value The integer whose bits we want to get
     * @param _width The width of the bits (in bits) we want to extract
     * @param _offset The offset of the bits (in bits) we want to extract
     * @return An integer containing _width bits of _value starting at the
     *         _offset bit
     */
    function bits(uint256 _value, uint256 _width, uint256 _offset) pure internal returns (uint) {
        return (_value / (2 ** _offset)) & (((2 ** _width)) - 1);
    }

    function sin_table_lookup(uint256 index) pure internal returns (uint16) {
        bytes memory table = sin_table;
        uint256 offset = (index + 1) * entry_bytes;
        uint16 trigint_value;
        assembly {
            trigint_value := mload(add(table, offset))
        }

        return trigint_value;
    }

    /**
     * Return the sine of an integer approximated angle as a signed 16-bit
     * integer.
     *
     * @param _angle A 16-bit angle. This divides the circle into 16384
     *               angle units, instead of the standard 360 degrees.
     * @return The sine result as a number in the range -32767 to 32767.
     */
    function sin(uint16 _angle) public pure returns (int) {
        uint256 interp = bits(_angle, INTERP_WIDTH, INTERP_OFFSET);
        uint256 index = bits(_angle, INDEX_WIDTH, INDEX_OFFSET);

        bool is_odd_quadrant = (_angle & QUADRANT_LOW_MASK) == 0;
        bool is_negative_quadrant = (_angle & QUADRANT_HIGH_MASK) != 0;

        if (!is_odd_quadrant) {
            index = SINE_TABLE_SIZE - 1 - index;
        }

        uint256 x1 = sin_table_lookup(index);
        uint256 x2 = sin_table_lookup(index + 1);
        uint256 approximation = ((x2 - x1) * interp) / (2 ** INTERP_WIDTH);

        int256 sine;
        if (is_odd_quadrant) {
            sine = int256(x1) + int256(approximation);
        } else {
            sine = int256(x2) - int256(approximation);
        }

        if (is_negative_quadrant) {
            sine *= -1;
        }

        return sine;
    }

    /**
     * Return the cos of an integer approximated angle.
     * It functions just like the sin() method but uses the trigonometric
     * identity sin(x + pi/2) = cos(x) to quickly calculate the cos.
     */
    function cos(uint16 _angle) public pure returns (int256) {
        if (_angle > ANGLES_IN_CYCLE - QUADRANT_LOW_MASK) {
            _angle = QUADRANT_LOW_MASK - ANGLES_IN_CYCLE - _angle;
        } else {
            _angle += QUADRANT_LOW_MASK;
        }
        return sin(_angle);
    }

}