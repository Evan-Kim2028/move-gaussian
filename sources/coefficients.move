/// Auto-generated Gaussian coefficient module.
/// Generated on 2025-12-06T23:05:07.921879+00:00 UTC by 07_export_for_move_gaussian.py.
module gaussian::coefficients {

    const SCALE: u128 = 1000000000000000000;
    const MAX_Z: u128 = 6000000000000000000;
    const EPS: u128 = 100000000;
    const P_LOW: u128 = 20000000000000000;
    const P_HIGH: u128 = 980000000000000000;

    const FNV_OFFSET_BASIS_128: u256 = 144066263297769815596495629667062367629;
    const FNV_PRIME_128: u256 = 309485009821345068724781371;
    const MOD_2_128: u256 = 340282366920938463463374607431768211456; // 2^128

    public fun scale(): u128 { SCALE }
    public fun max_z(): u128 { MAX_Z }
    public fun eps(): u128 { EPS }
    public fun p_low(): u128 { P_LOW }
    public fun p_high(): u128 { P_HIGH }

    const CDF_NUM_LEN: u64 = 13;
    const CDF_DEN_LEN: u64 = 13;
    public fun cdf_num_len(): u64 { CDF_NUM_LEN }
    public fun cdf_den_len(): u64 { CDF_DEN_LEN }
    const CDF_NUM_0_MAG: u128 = 500000000000000000;
    const CDF_NUM_0_NEG: bool = false;
    const CDF_NUM_1_MAG: u128 = 202783200542711800;
    const CDF_NUM_1_NEG: bool = false;
    const CDF_NUM_2_MAG: u128 = 3858755025623129;
    const CDF_NUM_2_NEG: bool = true;
    const CDF_NUM_3_MAG: u128 = 11990724892373883;
    const CDF_NUM_3_NEG: bool = false;
    const CDF_NUM_4_MAG: u128 = 9821445877008875;
    const CDF_NUM_4_NEG: bool = false;
    const CDF_NUM_5_MAG: u128 = 428553144348960;
    const CDF_NUM_5_NEG: bool = false;
    const CDF_NUM_6_MAG: u128 = 75031762951910;
    const CDF_NUM_6_NEG: bool = true;
    const CDF_NUM_7_MAG: u128 = 152292945143770;
    const CDF_NUM_7_NEG: bool = false;
    const CDF_NUM_8_MAG: u128 = 11488864967923;
    const CDF_NUM_8_NEG: bool = false;
    const CDF_NUM_9_MAG: u128 = 4621581948805;
    const CDF_NUM_9_NEG: bool = true;
    const CDF_NUM_10_MAG: u128 = 2225303281381;
    const CDF_NUM_10_NEG: bool = false;
    const CDF_NUM_11_MAG: u128 = 261982963157;
    const CDF_NUM_11_NEG: bool = true;
    const CDF_NUM_12_MAG: u128 = 34576100063;
    const CDF_NUM_12_NEG: bool = false;

    const CDF_DEN_0_MAG: u128 = 1000000000000000000;
    const CDF_DEN_0_NEG: bool = false;
    const CDF_DEN_1_MAG: u128 = 392318159714714800;
    const CDF_DEN_1_NEG: bool = true;
    const CDF_DEN_2_MAG: u128 = 305307092394795530;
    const CDF_DEN_2_NEG: bool = false;
    const CDF_DEN_3_MAG: u128 = 86637603680925630;
    const CDF_DEN_3_NEG: bool = true;
    const CDF_DEN_4_MAG: u128 = 36598917127631020;
    const CDF_DEN_4_NEG: bool = false;
    const CDF_DEN_5_MAG: u128 = 7691680921657243;
    const CDF_DEN_5_NEG: bool = true;
    const CDF_DEN_6_MAG: u128 = 2291266221525212;
    const CDF_DEN_6_NEG: bool = false;
    const CDF_DEN_7_MAG: u128 = 371453915370755;
    const CDF_DEN_7_NEG: bool = true;
    const CDF_DEN_8_MAG: u128 = 92212330692182;
    const CDF_DEN_8_NEG: bool = false;
    const CDF_DEN_9_MAG: u128 = 13011690648577;
    const CDF_DEN_9_NEG: bool = true;
    const CDF_DEN_10_MAG: u128 = 2788395097838;
    const CDF_DEN_10_NEG: bool = false;
    const CDF_DEN_11_MAG: u128 = 284107149822;
    const CDF_DEN_11_NEG: bool = true;
    const CDF_DEN_12_MAG: u128 = 34964019972;
    const CDF_DEN_12_NEG: bool = false;

    public fun cdf_num_coeff(i: u64): (u128, bool) {
        if (i == 0) {
            (CDF_NUM_0_MAG, CDF_NUM_0_NEG)
        } else if (i == 1) {
            (CDF_NUM_1_MAG, CDF_NUM_1_NEG)
        } else if (i == 2) {
            (CDF_NUM_2_MAG, CDF_NUM_2_NEG)
        } else if (i == 3) {
            (CDF_NUM_3_MAG, CDF_NUM_3_NEG)
        } else if (i == 4) {
            (CDF_NUM_4_MAG, CDF_NUM_4_NEG)
        } else if (i == 5) {
            (CDF_NUM_5_MAG, CDF_NUM_5_NEG)
        } else if (i == 6) {
            (CDF_NUM_6_MAG, CDF_NUM_6_NEG)
        } else if (i == 7) {
            (CDF_NUM_7_MAG, CDF_NUM_7_NEG)
        } else if (i == 8) {
            (CDF_NUM_8_MAG, CDF_NUM_8_NEG)
        } else if (i == 9) {
            (CDF_NUM_9_MAG, CDF_NUM_9_NEG)
        } else if (i == 10) {
            (CDF_NUM_10_MAG, CDF_NUM_10_NEG)
        } else if (i == 11) {
            (CDF_NUM_11_MAG, CDF_NUM_11_NEG)
        } else {
            (CDF_NUM_12_MAG, CDF_NUM_12_NEG)
        }
    }

    public fun cdf_den_coeff(i: u64): (u128, bool) {
        if (i == 0) {
            (CDF_DEN_0_MAG, CDF_DEN_0_NEG)
        } else if (i == 1) {
            (CDF_DEN_1_MAG, CDF_DEN_1_NEG)
        } else if (i == 2) {
            (CDF_DEN_2_MAG, CDF_DEN_2_NEG)
        } else if (i == 3) {
            (CDF_DEN_3_MAG, CDF_DEN_3_NEG)
        } else if (i == 4) {
            (CDF_DEN_4_MAG, CDF_DEN_4_NEG)
        } else if (i == 5) {
            (CDF_DEN_5_MAG, CDF_DEN_5_NEG)
        } else if (i == 6) {
            (CDF_DEN_6_MAG, CDF_DEN_6_NEG)
        } else if (i == 7) {
            (CDF_DEN_7_MAG, CDF_DEN_7_NEG)
        } else if (i == 8) {
            (CDF_DEN_8_MAG, CDF_DEN_8_NEG)
        } else if (i == 9) {
            (CDF_DEN_9_MAG, CDF_DEN_9_NEG)
        } else if (i == 10) {
            (CDF_DEN_10_MAG, CDF_DEN_10_NEG)
        } else if (i == 11) {
            (CDF_DEN_11_MAG, CDF_DEN_11_NEG)
        } else {
            (CDF_DEN_12_MAG, CDF_DEN_12_NEG)
        }
    }

    const CDF_CHECKSUM: u128 = 12428030454182378736638227372090014573;
    const PDF_NUM_LEN: u64 = 21;
    const PDF_DEN_LEN: u64 = 21;
    public fun pdf_num_len(): u64 { PDF_NUM_LEN }
    public fun pdf_den_len(): u64 { PDF_DEN_LEN }
    const PDF_NUM_0_MAG: u128 = 398942280401794500;
    const PDF_NUM_0_NEG: bool = false;
    const PDF_NUM_1_MAG: u128 = 2616869327678082;
    const PDF_NUM_1_NEG: bool = true;
    const PDF_NUM_2_MAG: u128 = 81215607262716770;
    const PDF_NUM_2_NEG: bool = true;
    const PDF_NUM_3_MAG: u128 = 521765429525921;
    const PDF_NUM_3_NEG: bool = false;
    const PDF_NUM_4_MAG: u128 = 7665030475511794;
    const PDF_NUM_4_NEG: bool = false;
    const PDF_NUM_5_MAG: u128 = 47692548065206;
    const PDF_NUM_5_NEG: bool = true;
    const PDF_NUM_6_MAG: u128 = 441544478326693;
    const PDF_NUM_6_NEG: bool = true;
    const PDF_NUM_7_MAG: u128 = 2621767754800;
    const PDF_NUM_7_NEG: bool = false;
    const PDF_NUM_8_MAG: u128 = 17185617750772;
    const PDF_NUM_8_NEG: bool = false;
    const PDF_NUM_9_MAG: u128 = 95456109290;
    const PDF_NUM_9_NEG: bool = true;
    const PDF_NUM_10_MAG: u128 = 471973901294;
    const PDF_NUM_10_NEG: bool = true;
    const PDF_NUM_11_MAG: u128 = 2384962441;
    const PDF_NUM_11_NEG: bool = false;
    const PDF_NUM_12_MAG: u128 = 9255684409;
    const PDF_NUM_12_NEG: bool = false;
    const PDF_NUM_13_MAG: u128 = 40845497;
    const PDF_NUM_13_NEG: bool = true;
    const PDF_NUM_14_MAG: u128 = 127863081;
    const PDF_NUM_14_NEG: bool = true;
    const PDF_NUM_15_MAG: u128 = 461771;
    const PDF_NUM_15_NEG: bool = false;
    const PDF_NUM_16_MAG: u128 = 1189541;
    const PDF_NUM_16_NEG: bool = false;
    const PDF_NUM_17_MAG: u128 = 3122;
    const PDF_NUM_17_NEG: bool = true;
    const PDF_NUM_18_MAG: u128 = 6721;
    const PDF_NUM_18_NEG: bool = true;
    const PDF_NUM_19_MAG: u128 = 10;
    const PDF_NUM_19_NEG: bool = false;
    const PDF_NUM_20_MAG: u128 = 17;
    const PDF_NUM_20_NEG: bool = false;

    const PDF_DEN_0_MAG: u128 = 1000000000000000000;
    const PDF_DEN_0_NEG: bool = false;
    const PDF_DEN_1_MAG: u128 = 6559518648393350;
    const PDF_DEN_1_NEG: bool = true;
    const PDF_DEN_2_MAG: u128 = 296422662498152900;
    const PDF_DEN_2_NEG: bool = false;
    const PDF_DEN_3_MAG: u128 = 1971887344610872;
    const PDF_DEN_3_NEG: bool = true;
    const PDF_DEN_4_MAG: u128 = 42424713358647944;
    const PDF_DEN_4_NEG: bool = false;
    const PDF_DEN_5_MAG: u128 = 285551331422719;
    const PDF_DEN_5_NEG: bool = true;
    const PDF_DEN_6_MAG: u128 = 3886069330760721;
    const PDF_DEN_6_NEG: bool = false;
    const PDF_DEN_7_MAG: u128 = 26374589412830;
    const PDF_DEN_7_NEG: bool = true;
    const PDF_DEN_8_MAG: u128 = 254328918742173;
    const PDF_DEN_8_NEG: bool = false;
    const PDF_DEN_9_MAG: u128 = 1731556555230;
    const PDF_DEN_9_NEG: bool = true;
    const PDF_DEN_10_MAG: u128 = 12553573576495;
    const PDF_DEN_10_NEG: bool = false;
    const PDF_DEN_11_MAG: u128 = 85048363055;
    const PDF_DEN_11_NEG: bool = true;
    const PDF_DEN_12_MAG: u128 = 479639927274;
    const PDF_DEN_12_NEG: bool = false;
    const PDF_DEN_13_MAG: u128 = 3190270106;
    const PDF_DEN_13_NEG: bool = true;
    const PDF_DEN_14_MAG: u128 = 14267082301;
    const PDF_DEN_14_NEG: bool = false;
    const PDF_DEN_15_MAG: u128 = 91055972;
    const PDF_DEN_15_NEG: bool = true;
    const PDF_DEN_16_MAG: u128 = 325097367;
    const PDF_DEN_16_NEG: bool = false;
    const PDF_DEN_17_MAG: u128 = 1878764;
    const PDF_DEN_17_NEG: bool = true;
    const PDF_DEN_18_MAG: u128 = 5353981;
    const PDF_DEN_18_NEG: bool = false;
    const PDF_DEN_19_MAG: u128 = 26367;
    const PDF_DEN_19_NEG: bool = true;
    const PDF_DEN_20_MAG: u128 = 55678;
    const PDF_DEN_20_NEG: bool = false;

    public fun pdf_num_coeff(i: u64): (u128, bool) {
        if (i == 0) {
            (PDF_NUM_0_MAG, PDF_NUM_0_NEG)
        } else if (i == 1) {
            (PDF_NUM_1_MAG, PDF_NUM_1_NEG)
        } else if (i == 2) {
            (PDF_NUM_2_MAG, PDF_NUM_2_NEG)
        } else if (i == 3) {
            (PDF_NUM_3_MAG, PDF_NUM_3_NEG)
        } else if (i == 4) {
            (PDF_NUM_4_MAG, PDF_NUM_4_NEG)
        } else if (i == 5) {
            (PDF_NUM_5_MAG, PDF_NUM_5_NEG)
        } else if (i == 6) {
            (PDF_NUM_6_MAG, PDF_NUM_6_NEG)
        } else if (i == 7) {
            (PDF_NUM_7_MAG, PDF_NUM_7_NEG)
        } else if (i == 8) {
            (PDF_NUM_8_MAG, PDF_NUM_8_NEG)
        } else if (i == 9) {
            (PDF_NUM_9_MAG, PDF_NUM_9_NEG)
        } else if (i == 10) {
            (PDF_NUM_10_MAG, PDF_NUM_10_NEG)
        } else if (i == 11) {
            (PDF_NUM_11_MAG, PDF_NUM_11_NEG)
        } else if (i == 12) {
            (PDF_NUM_12_MAG, PDF_NUM_12_NEG)
        } else if (i == 13) {
            (PDF_NUM_13_MAG, PDF_NUM_13_NEG)
        } else if (i == 14) {
            (PDF_NUM_14_MAG, PDF_NUM_14_NEG)
        } else if (i == 15) {
            (PDF_NUM_15_MAG, PDF_NUM_15_NEG)
        } else if (i == 16) {
            (PDF_NUM_16_MAG, PDF_NUM_16_NEG)
        } else if (i == 17) {
            (PDF_NUM_17_MAG, PDF_NUM_17_NEG)
        } else if (i == 18) {
            (PDF_NUM_18_MAG, PDF_NUM_18_NEG)
        } else if (i == 19) {
            (PDF_NUM_19_MAG, PDF_NUM_19_NEG)
        } else {
            (PDF_NUM_20_MAG, PDF_NUM_20_NEG)
        }
    }

    public fun pdf_den_coeff(i: u64): (u128, bool) {
        if (i == 0) {
            (PDF_DEN_0_MAG, PDF_DEN_0_NEG)
        } else if (i == 1) {
            (PDF_DEN_1_MAG, PDF_DEN_1_NEG)
        } else if (i == 2) {
            (PDF_DEN_2_MAG, PDF_DEN_2_NEG)
        } else if (i == 3) {
            (PDF_DEN_3_MAG, PDF_DEN_3_NEG)
        } else if (i == 4) {
            (PDF_DEN_4_MAG, PDF_DEN_4_NEG)
        } else if (i == 5) {
            (PDF_DEN_5_MAG, PDF_DEN_5_NEG)
        } else if (i == 6) {
            (PDF_DEN_6_MAG, PDF_DEN_6_NEG)
        } else if (i == 7) {
            (PDF_DEN_7_MAG, PDF_DEN_7_NEG)
        } else if (i == 8) {
            (PDF_DEN_8_MAG, PDF_DEN_8_NEG)
        } else if (i == 9) {
            (PDF_DEN_9_MAG, PDF_DEN_9_NEG)
        } else if (i == 10) {
            (PDF_DEN_10_MAG, PDF_DEN_10_NEG)
        } else if (i == 11) {
            (PDF_DEN_11_MAG, PDF_DEN_11_NEG)
        } else if (i == 12) {
            (PDF_DEN_12_MAG, PDF_DEN_12_NEG)
        } else if (i == 13) {
            (PDF_DEN_13_MAG, PDF_DEN_13_NEG)
        } else if (i == 14) {
            (PDF_DEN_14_MAG, PDF_DEN_14_NEG)
        } else if (i == 15) {
            (PDF_DEN_15_MAG, PDF_DEN_15_NEG)
        } else if (i == 16) {
            (PDF_DEN_16_MAG, PDF_DEN_16_NEG)
        } else if (i == 17) {
            (PDF_DEN_17_MAG, PDF_DEN_17_NEG)
        } else if (i == 18) {
            (PDF_DEN_18_MAG, PDF_DEN_18_NEG)
        } else if (i == 19) {
            (PDF_DEN_19_MAG, PDF_DEN_19_NEG)
        } else {
            (PDF_DEN_20_MAG, PDF_DEN_20_NEG)
        }
    }

    const PDF_CHECKSUM: u128 = 39466689394914504909406767938060234167;

    const PPF_CENTRAL_NUM_LEN: u64 = 18;
    const PPF_CENTRAL_DEN_LEN: u64 = 18;
    public fun ppf_central_num_len(): u64 { PPF_CENTRAL_NUM_LEN }
    public fun ppf_central_den_len(): u64 { PPF_CENTRAL_DEN_LEN }
    const PPF_CENTRAL_NUM_0_MAG: u128 = 3149768420253117400;
    const PPF_CENTRAL_NUM_0_NEG: bool = true;
    const PPF_CENTRAL_NUM_1_MAG: u128 = 629066642359135600000;
    const PPF_CENTRAL_NUM_1_NEG: bool = true;
    const PPF_CENTRAL_NUM_2_MAG: u128 = 16967899171534703000000;
    const PPF_CENTRAL_NUM_2_NEG: bool = true;
    const PPF_CENTRAL_NUM_3_MAG: u128 = 40206829839131340000000;
    const PPF_CENTRAL_NUM_3_NEG: bool = true;
    const PPF_CENTRAL_NUM_4_MAG: u128 = 317985140319403760000000;
    const PPF_CENTRAL_NUM_4_NEG: bool = false;
    const PPF_CENTRAL_NUM_5_MAG: u128 = 268477636357400270000000;
    const PPF_CENTRAL_NUM_5_NEG: bool = true;
    const PPF_CENTRAL_NUM_6_MAG: u128 = 168422329089218700000000;
    const PPF_CENTRAL_NUM_6_NEG: bool = true;
    const PPF_CENTRAL_NUM_7_MAG: u128 = 21629704131823550000000;
    const PPF_CENTRAL_NUM_7_NEG: bool = true;
    const PPF_CENTRAL_NUM_8_MAG: u128 = 193032226834201400000000;
    const PPF_CENTRAL_NUM_8_NEG: bool = false;
    const PPF_CENTRAL_NUM_9_MAG: u128 = 38219211340184200000000;
    const PPF_CENTRAL_NUM_9_NEG: bool = false;
    const PPF_CENTRAL_NUM_10_MAG: u128 = 99812930913486470000000;
    const PPF_CENTRAL_NUM_10_NEG: bool = false;
    const PPF_CENTRAL_NUM_11_MAG: u128 = 58476190394549940000000;
    const PPF_CENTRAL_NUM_11_NEG: bool = false;
    const PPF_CENTRAL_NUM_12_MAG: u128 = 158888404694161630000000;
    const PPF_CENTRAL_NUM_12_NEG: bool = true;
    const PPF_CENTRAL_NUM_13_MAG: u128 = 144760892670281180000000;
    const PPF_CENTRAL_NUM_13_NEG: bool = true;
    const PPF_CENTRAL_NUM_14_MAG: u128 = 14764889158885430000000;
    const PPF_CENTRAL_NUM_14_NEG: bool = false;
    const PPF_CENTRAL_NUM_15_MAG: u128 = 49705977958957270000000;
    const PPF_CENTRAL_NUM_15_NEG: bool = false;
    const PPF_CENTRAL_NUM_16_MAG: u128 = 120579384255211290000000;
    const PPF_CENTRAL_NUM_16_NEG: bool = false;
    const PPF_CENTRAL_NUM_17_MAG: u128 = 72594072850240850000000;
    const PPF_CENTRAL_NUM_17_NEG: bool = true;

    const PPF_CENTRAL_DEN_0_MAG: u128 = 1000000000000000000;
    const PPF_CENTRAL_DEN_0_NEG: bool = false;
    const PPF_CENTRAL_DEN_1_MAG: u128 = 269684345103724970000;
    const PPF_CENTRAL_DEN_1_NEG: bool = false;
    const PPF_CENTRAL_DEN_2_MAG: u128 = 10372185805823563000000;
    const PPF_CENTRAL_DEN_2_NEG: bool = false;
    const PPF_CENTRAL_DEN_3_MAG: u128 = 70892565052848530000000;
    const PPF_CENTRAL_DEN_3_NEG: bool = false;
    const PPF_CENTRAL_DEN_4_MAG: u128 = 76109909787066970000000;
    const PPF_CENTRAL_DEN_4_NEG: bool = true;
    const PPF_CENTRAL_DEN_5_MAG: u128 = 251007572919404350000000;
    const PPF_CENTRAL_DEN_5_NEG: bool = true;
    const PPF_CENTRAL_DEN_6_MAG: u128 = 280204102498749700000000;
    const PPF_CENTRAL_DEN_6_NEG: bool = false;
    const PPF_CENTRAL_DEN_7_MAG: u128 = 115608407221849100000000;
    const PPF_CENTRAL_DEN_7_NEG: bool = true;
    const PPF_CENTRAL_DEN_8_MAG: u128 = 246907944430908400000000;
    const PPF_CENTRAL_DEN_8_NEG: bool = false;
    const PPF_CENTRAL_DEN_9_MAG: u128 = 5073125714556985000000;
    const PPF_CENTRAL_DEN_9_NEG: bool = true;
    const PPF_CENTRAL_DEN_10_MAG: u128 = 201992042891743460000000;
    const PPF_CENTRAL_DEN_10_NEG: bool = true;
    const PPF_CENTRAL_DEN_11_MAG: u128 = 42553226331296690000000;
    const PPF_CENTRAL_DEN_11_NEG: bool = false;
    const PPF_CENTRAL_DEN_12_MAG: u128 = 14270211318970457000000;
    const PPF_CENTRAL_DEN_12_NEG: bool = true;
    const PPF_CENTRAL_DEN_13_MAG: u128 = 136995682139616900000000;
    const PPF_CENTRAL_DEN_13_NEG: bool = true;
    const PPF_CENTRAL_DEN_14_MAG: u128 = 109540618832453700000000;
    const PPF_CENTRAL_DEN_14_NEG: bool = false;
    const PPF_CENTRAL_DEN_15_MAG: u128 = 192188548614780200000000;
    const PPF_CENTRAL_DEN_15_NEG: bool = false;
    const PPF_CENTRAL_DEN_16_MAG: u128 = 194095325908778920000000;
    const PPF_CENTRAL_DEN_16_NEG: bool = true;
    const PPF_CENTRAL_DEN_17_MAG: u128 = 42221140016529350000000;
    const PPF_CENTRAL_DEN_17_NEG: bool = false;

    public fun ppf_central_num_coeff(i: u64): (u128, bool) {
        if (i == 0) {
            (PPF_CENTRAL_NUM_0_MAG, PPF_CENTRAL_NUM_0_NEG)
        } else if (i == 1) {
            (PPF_CENTRAL_NUM_1_MAG, PPF_CENTRAL_NUM_1_NEG)
        } else if (i == 2) {
            (PPF_CENTRAL_NUM_2_MAG, PPF_CENTRAL_NUM_2_NEG)
        } else if (i == 3) {
            (PPF_CENTRAL_NUM_3_MAG, PPF_CENTRAL_NUM_3_NEG)
        } else if (i == 4) {
            (PPF_CENTRAL_NUM_4_MAG, PPF_CENTRAL_NUM_4_NEG)
        } else if (i == 5) {
            (PPF_CENTRAL_NUM_5_MAG, PPF_CENTRAL_NUM_5_NEG)
        } else if (i == 6) {
            (PPF_CENTRAL_NUM_6_MAG, PPF_CENTRAL_NUM_6_NEG)
        } else if (i == 7) {
            (PPF_CENTRAL_NUM_7_MAG, PPF_CENTRAL_NUM_7_NEG)
        } else if (i == 8) {
            (PPF_CENTRAL_NUM_8_MAG, PPF_CENTRAL_NUM_8_NEG)
        } else if (i == 9) {
            (PPF_CENTRAL_NUM_9_MAG, PPF_CENTRAL_NUM_9_NEG)
        } else if (i == 10) {
            (PPF_CENTRAL_NUM_10_MAG, PPF_CENTRAL_NUM_10_NEG)
        } else if (i == 11) {
            (PPF_CENTRAL_NUM_11_MAG, PPF_CENTRAL_NUM_11_NEG)
        } else if (i == 12) {
            (PPF_CENTRAL_NUM_12_MAG, PPF_CENTRAL_NUM_12_NEG)
        } else if (i == 13) {
            (PPF_CENTRAL_NUM_13_MAG, PPF_CENTRAL_NUM_13_NEG)
        } else if (i == 14) {
            (PPF_CENTRAL_NUM_14_MAG, PPF_CENTRAL_NUM_14_NEG)
        } else if (i == 15) {
            (PPF_CENTRAL_NUM_15_MAG, PPF_CENTRAL_NUM_15_NEG)
        } else if (i == 16) {
            (PPF_CENTRAL_NUM_16_MAG, PPF_CENTRAL_NUM_16_NEG)
        } else {
            (PPF_CENTRAL_NUM_17_MAG, PPF_CENTRAL_NUM_17_NEG)
        }
    }

    public fun ppf_central_den_coeff(i: u64): (u128, bool) {
        if (i == 0) {
            (PPF_CENTRAL_DEN_0_MAG, PPF_CENTRAL_DEN_0_NEG)
        } else if (i == 1) {
            (PPF_CENTRAL_DEN_1_MAG, PPF_CENTRAL_DEN_1_NEG)
        } else if (i == 2) {
            (PPF_CENTRAL_DEN_2_MAG, PPF_CENTRAL_DEN_2_NEG)
        } else if (i == 3) {
            (PPF_CENTRAL_DEN_3_MAG, PPF_CENTRAL_DEN_3_NEG)
        } else if (i == 4) {
            (PPF_CENTRAL_DEN_4_MAG, PPF_CENTRAL_DEN_4_NEG)
        } else if (i == 5) {
            (PPF_CENTRAL_DEN_5_MAG, PPF_CENTRAL_DEN_5_NEG)
        } else if (i == 6) {
            (PPF_CENTRAL_DEN_6_MAG, PPF_CENTRAL_DEN_6_NEG)
        } else if (i == 7) {
            (PPF_CENTRAL_DEN_7_MAG, PPF_CENTRAL_DEN_7_NEG)
        } else if (i == 8) {
            (PPF_CENTRAL_DEN_8_MAG, PPF_CENTRAL_DEN_8_NEG)
        } else if (i == 9) {
            (PPF_CENTRAL_DEN_9_MAG, PPF_CENTRAL_DEN_9_NEG)
        } else if (i == 10) {
            (PPF_CENTRAL_DEN_10_MAG, PPF_CENTRAL_DEN_10_NEG)
        } else if (i == 11) {
            (PPF_CENTRAL_DEN_11_MAG, PPF_CENTRAL_DEN_11_NEG)
        } else if (i == 12) {
            (PPF_CENTRAL_DEN_12_MAG, PPF_CENTRAL_DEN_12_NEG)
        } else if (i == 13) {
            (PPF_CENTRAL_DEN_13_MAG, PPF_CENTRAL_DEN_13_NEG)
        } else if (i == 14) {
            (PPF_CENTRAL_DEN_14_MAG, PPF_CENTRAL_DEN_14_NEG)
        } else if (i == 15) {
            (PPF_CENTRAL_DEN_15_MAG, PPF_CENTRAL_DEN_15_NEG)
        } else if (i == 16) {
            (PPF_CENTRAL_DEN_16_MAG, PPF_CENTRAL_DEN_16_NEG)
        } else {
            (PPF_CENTRAL_DEN_17_MAG, PPF_CENTRAL_DEN_17_NEG)
        }
    }

    const PPF_CENTRAL_CHECKSUM: u128 = 333772141461594105586713657887433327624;
    const PPF_TAIL_NUM_LEN: u64 = 6;
    const PPF_TAIL_DEN_LEN: u64 = 6;
    public fun ppf_tail_num_len(): u64 { PPF_TAIL_NUM_LEN }
    public fun ppf_tail_den_len(): u64 { PPF_TAIL_DEN_LEN }
    const PPF_TAIL_NUM_0_MAG: u128 = 2567643860925250000;
    const PPF_TAIL_NUM_0_NEG: bool = false;
    const PPF_TAIL_NUM_1_MAG: u128 = 831114984169109000;
    const PPF_TAIL_NUM_1_NEG: bool = true;
    const PPF_TAIL_NUM_2_MAG: u128 = 436399206269726300;
    const PPF_TAIL_NUM_2_NEG: bool = true;
    const PPF_TAIL_NUM_3_MAG: u128 = 315711266783981300;
    const PPF_TAIL_NUM_3_NEG: bool = false;
    const PPF_TAIL_NUM_4_MAG: u128 = 619836602935362600;
    const PPF_TAIL_NUM_4_NEG: bool = true;
    const PPF_TAIL_NUM_5_MAG: u128 = 137328578041246460;
    const PPF_TAIL_NUM_5_NEG: bool = true;

    const PPF_TAIL_DEN_0_MAG: u128 = 1000000000000000000;
    const PPF_TAIL_DEN_0_NEG: bool = false;
    const PPF_TAIL_DEN_1_MAG: u128 = 1242465112096483600;
    const PPF_TAIL_DEN_1_NEG: bool = false;
    const PPF_TAIL_DEN_2_MAG: u128 = 188139865862538400;
    const PPF_TAIL_DEN_2_NEG: bool = false;
    const PPF_TAIL_DEN_3_MAG: u128 = 628912910895590900;
    const PPF_TAIL_DEN_3_NEG: bool = false;
    const PPF_TAIL_DEN_4_MAG: u128 = 137109655631473570;
    const PPF_TAIL_DEN_4_NEG: bool = false;
    const PPF_TAIL_DEN_5_MAG: u128 = 3362579729949;
    const PPF_TAIL_DEN_5_NEG: bool = false;

    public fun ppf_tail_num_coeff(i: u64): (u128, bool) {
        if (i == 0) {
            (PPF_TAIL_NUM_0_MAG, PPF_TAIL_NUM_0_NEG)
        } else if (i == 1) {
            (PPF_TAIL_NUM_1_MAG, PPF_TAIL_NUM_1_NEG)
        } else if (i == 2) {
            (PPF_TAIL_NUM_2_MAG, PPF_TAIL_NUM_2_NEG)
        } else if (i == 3) {
            (PPF_TAIL_NUM_3_MAG, PPF_TAIL_NUM_3_NEG)
        } else if (i == 4) {
            (PPF_TAIL_NUM_4_MAG, PPF_TAIL_NUM_4_NEG)
        } else {
            (PPF_TAIL_NUM_5_MAG, PPF_TAIL_NUM_5_NEG)
        }
    }

    public fun ppf_tail_den_coeff(i: u64): (u128, bool) {
        if (i == 0) {
            (PPF_TAIL_DEN_0_MAG, PPF_TAIL_DEN_0_NEG)
        } else if (i == 1) {
            (PPF_TAIL_DEN_1_MAG, PPF_TAIL_DEN_1_NEG)
        } else if (i == 2) {
            (PPF_TAIL_DEN_2_MAG, PPF_TAIL_DEN_2_NEG)
        } else if (i == 3) {
            (PPF_TAIL_DEN_3_MAG, PPF_TAIL_DEN_3_NEG)
        } else if (i == 4) {
            (PPF_TAIL_DEN_4_MAG, PPF_TAIL_DEN_4_NEG)
        } else {
            (PPF_TAIL_DEN_5_MAG, PPF_TAIL_DEN_5_NEG)
        }
    }

    const PPF_TAIL_CHECKSUM: u128 = 58896132505575964821144987038370786797;

    fun fnv_update(acc: u256, value: u256): u256 {
        let xored = acc ^ value;
        (xored * FNV_PRIME_128) % MOD_2_128
    }

    fun checksum_cdf_num(): u128 {
        let mut acc: u256 = FNV_OFFSET_BASIS_128;
        let mut i: u64 = 0;
        while (i < CDF_NUM_LEN) {
            let (mag, neg) = cdf_num_coeff(i);
            acc = fnv_update(acc, (mag as u256));
            acc = fnv_update(acc, if (neg) { 1 } else { 0 });
            i = i + 1;
        };
        acc = fnv_update(acc, (CDF_NUM_LEN as u256));
        (acc % MOD_2_128) as u128
    }

    fun checksum_cdf_den(): u128 {
        let mut acc: u256 = FNV_OFFSET_BASIS_128;
        let mut i: u64 = 0;
        while (i < CDF_DEN_LEN) {
            let (mag, neg) = cdf_den_coeff(i);
            acc = fnv_update(acc, (mag as u256));
            acc = fnv_update(acc, if (neg) { 1 } else { 0 });
            i = i + 1;
        };
        acc = fnv_update(acc, (CDF_DEN_LEN as u256));
        (acc % MOD_2_128) as u128
    }

    fun checksum_pdf_num(): u128 {
        let mut acc: u256 = FNV_OFFSET_BASIS_128;
        let mut i: u64 = 0;
        while (i < PDF_NUM_LEN) {
            let (mag, neg) = pdf_num_coeff(i);
            acc = fnv_update(acc, (mag as u256));
            acc = fnv_update(acc, if (neg) { 1 } else { 0 });
            i = i + 1;
        };
        acc = fnv_update(acc, (PDF_NUM_LEN as u256));
        (acc % MOD_2_128) as u128
    }

    fun checksum_pdf_den(): u128 {
        let mut acc: u256 = FNV_OFFSET_BASIS_128;
        let mut i: u64 = 0;
        while (i < PDF_DEN_LEN) {
            let (mag, neg) = pdf_den_coeff(i);
            acc = fnv_update(acc, (mag as u256));
            acc = fnv_update(acc, if (neg) { 1 } else { 0 });
            i = i + 1;
        };
        acc = fnv_update(acc, (PDF_DEN_LEN as u256));
        (acc % MOD_2_128) as u128
    }

    fun checksum_ppf_central_num(): u128 {
        let mut acc: u256 = FNV_OFFSET_BASIS_128;
        let mut i: u64 = 0;
        while (i < PPF_CENTRAL_NUM_LEN) {
            let (mag, neg) = ppf_central_num_coeff(i);
            acc = fnv_update(acc, (mag as u256));
            acc = fnv_update(acc, if (neg) { 1 } else { 0 });
            i = i + 1;
        };
        acc = fnv_update(acc, (PPF_CENTRAL_NUM_LEN as u256));
        (acc % MOD_2_128) as u128
    }

    fun checksum_ppf_central_den(): u128 {
        let mut acc: u256 = FNV_OFFSET_BASIS_128;
        let mut i: u64 = 0;
        while (i < PPF_CENTRAL_DEN_LEN) {
            let (mag, neg) = ppf_central_den_coeff(i);
            acc = fnv_update(acc, (mag as u256));
            acc = fnv_update(acc, if (neg) { 1 } else { 0 });
            i = i + 1;
        };
        acc = fnv_update(acc, (PPF_CENTRAL_DEN_LEN as u256));
        (acc % MOD_2_128) as u128
    }

    fun checksum_ppf_tail_num(): u128 {
        let mut acc: u256 = FNV_OFFSET_BASIS_128;
        let mut i: u64 = 0;
        while (i < PPF_TAIL_NUM_LEN) {
            let (mag, neg) = ppf_tail_num_coeff(i);
            acc = fnv_update(acc, (mag as u256));
            acc = fnv_update(acc, if (neg) { 1 } else { 0 });
            i = i + 1;
        };
        acc = fnv_update(acc, (PPF_TAIL_NUM_LEN as u256));
        (acc % MOD_2_128) as u128
    }

    fun checksum_ppf_tail_den(): u128 {
        let mut acc: u256 = FNV_OFFSET_BASIS_128;
        let mut i: u64 = 0;
        while (i < PPF_TAIL_DEN_LEN) {
            let (mag, neg) = ppf_tail_den_coeff(i);
            acc = fnv_update(acc, (mag as u256));
            acc = fnv_update(acc, if (neg) { 1 } else { 0 });
            i = i + 1;
        };
        acc = fnv_update(acc, (PPF_TAIL_DEN_LEN as u256));
        (acc % MOD_2_128) as u128
    }

    #[test]
    fun test_constants() {
        assert!(scale() == SCALE, 0);
        assert!(max_z() == MAX_Z, 1);
        assert!(eps() == EPS, 2);
        assert!(p_low() == P_LOW, 3);
        assert!(p_high() == P_HIGH, 4);
    }

    #[test]
    fun test_cdf_lengths() {
        assert!(cdf_num_len() == CDF_NUM_LEN, 0);
        assert!(cdf_den_len() == CDF_DEN_LEN, 1);
    }

    #[test]
    fun test_ppf_lengths() {
        assert!(ppf_central_num_len() == PPF_CENTRAL_NUM_LEN, 0);
        assert!(ppf_tail_num_len() == PPF_TAIL_NUM_LEN, 1);
    }

    #[test]
    fun test_checksums_match() {
        let cdf = checksum_cdf_num() ^ checksum_cdf_den();
        let pdf = checksum_pdf_num() ^ checksum_pdf_den();
        let ppf_c = checksum_ppf_central_num() ^ checksum_ppf_central_den();
        let ppf_t = checksum_ppf_tail_num() ^ checksum_ppf_tail_den();
        assert!(cdf == CDF_CHECKSUM, 0);
        assert!(pdf == PDF_CHECKSUM, 1);
        assert!(ppf_c == PPF_CENTRAL_CHECKSUM, 2);
        assert!(ppf_t == PPF_TAIL_CHECKSUM, 3);
    }

}
