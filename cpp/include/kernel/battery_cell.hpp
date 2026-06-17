// =============================================================================
// cpp/include/kernel/battery_cell.hpp
// ProbOS Week 4 -- BatteryCell C++ implementation
//
// Mirrors BatteryModel2Cell in python/src/battery_model.py.
// All computation is plain C++20 -- no Python dependency.
//
// State vector (8 doubles):
//   [T1, T2, c_SEI1, c_SEI2, c_an1, c_an2, c_ca1, c_ca2]
//
// Parameter vector (15 doubles):
//   [Ea_SEI, A_SEI, H_SEI, Ea_an, A_an, H_an,
//    Ea_ca,  A_ca,  H_ca,  m,     Cp,   h,  A_surf, T_amb, T_onset]
// =============================================================================

#pragma once

#include <array>
#include <cmath>
#include <algorithm>

namespace probos {
namespace kernel {

// ============================================================
// Constants
// ============================================================
inline constexpr int    STATE_DIM  = 8;
inline constexpr int    PARAM_DIM  = 15;
inline constexpr double R_GAS      = 8.314462;   // J/(mol K)
inline constexpr double T_MIN      = 273.15;     // K
inline constexpr double T_MAX      = 5000.0;     // K

// ============================================================
// State and Param types
// ============================================================
using State = std::array<double, STATE_DIM>;
using Param = std::array<double, PARAM_DIM>;

// State indices
enum StateIdx : int {
    T1     = 0, T2     = 1,
    C_SEI1 = 2, C_SEI2 = 3,
    C_AN1  = 4, C_AN2  = 5,
    C_CA1  = 6, C_CA2  = 7,
};

// Parameter indices
enum ParamIdx : int {
    P_EA_SEI  = 0, P_A_SEI  = 1, P_H_SEI = 2,
    P_EA_AN   = 3, P_A_AN   = 4, P_H_AN  = 5,
    P_EA_CA   = 6, P_A_CA   = 7, P_H_CA  = 8,
    P_M_CELL  = 9, P_CP     = 10, P_H_CONV = 11,
    P_A_SURF  = 12, P_T_AMB = 13, P_T_ONSET = 14,
};

// ============================================================
// BatteryCell: single-particle forward step
// ============================================================
class BatteryCell {
public:
    // Nominal parameters from Kim et al. (2007)
    static Param nominal_params() noexcept {
        return {
            1.3508e5,  // Ea_SEI  [J/mol]
            1.667e15,  // A_SEI   [s^-1]
            2.5e5,     // H_SEI   [J/kg]
            1.3508e5,  // Ea_an   [J/mol]
            2.5e13,    // A_an    [s^-1]
            1.714e6,   // H_an    [J/kg]
            1.396e5,   // Ea_ca   [J/mol]
            1.0e9,     // A_ca    [s^-1]
            3.14e5,    // H_ca    [J/kg]
            0.045,     // m_cell  [kg]
            800.0,     // Cp      [J/(kg K)]
            5.0,       // h_conv  [W/(m^2 K)]
            3.5e-3,    // A_surf  [m^2]
            298.15,    // T_amb   [K]
            403.15,    // T_onset [K]
        };
    }

    // Initial state: both cells at onset temperature, all concentrations = 1
    static State initial_state() noexcept {
        return {403.15, 403.15, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0};
    }

    // --------------------------------------------------------
    // forward_step: explicit Euler step for one particle
    // Called N times per timestep in the serial version.
    // In OpenMP version, called in parallel across N particles.
    // --------------------------------------------------------
    static State forward_step(
        const State& s,
        const Param& p,
        double dt
    ) noexcept {
        // Extract state
        double T1     = s[T1_IDX];
        double T2     = s[T2_IDX];
        double c_sei1 = s[C_SEI1]; double c_sei2 = s[C_SEI2];
        double c_an1  = s[C_AN1];  double c_an2  = s[C_AN2];
        double c_ca1  = s[C_CA1];  double c_ca2  = s[C_CA2];

        // Extract params
        double Ea_SEI = p[P_EA_SEI]; double A_SEI = p[P_A_SEI]; double H_SEI = p[P_H_SEI];
        double Ea_an  = p[P_EA_AN];  double A_an  = p[P_A_AN];  double H_an  = p[P_H_AN];
        double Ea_ca  = p[P_EA_CA];  double A_ca  = p[P_A_CA];  double H_ca  = p[P_H_CA];
        double m      = p[P_M_CELL]; double Cp    = p[P_CP];
        double h      = p[P_H_CONV]; double A_s   = p[P_A_SURF];
        double T_amb  = p[P_T_AMB];

        // Clip temperatures
        double T1s = std::clamp(T1, T_MIN, T_MAX);
        double T2s = std::clamp(T2, T_MIN, T_MAX);

        // Arrhenius rates
        double k_sei1 = A_SEI * std::exp(-Ea_SEI / (R_GAS * T1s));
        double k_an1  = A_an  * std::exp(-Ea_an  / (R_GAS * T1s));
        double k_ca1  = A_ca  * std::exp(-Ea_ca  / (R_GAS * T1s));
        double k_sei2 = A_SEI * std::exp(-Ea_SEI / (R_GAS * T2s));
        double k_an2  = A_an  * std::exp(-Ea_an  / (R_GAS * T2s));
        double k_ca2  = A_ca  * std::exp(-Ea_ca  / (R_GAS * T2s));

        // Concentration rates
        auto clip_c = [](double c) { return std::clamp(c, 0.0, 1.0); };
        double dc_sei1 = -k_sei1 * clip_c(c_sei1);
        double dc_sei2 = -k_sei2 * clip_c(c_sei2);
        double dc_an1  = -k_an1  * clip_c(c_an1);
        double dc_an2  = -k_an2  * clip_c(c_an2);
        double dc_ca1  = -k_ca1  * clip_c(c_ca1);
        double dc_ca2  = -k_ca2  * clip_c(c_ca2);

        // Heat generation
        double Q_sei1 = H_SEI * m * (-dc_sei1);
        double Q_an1  = H_an  * m * (-dc_an1);
        double Q_ca1  = H_ca  * m * (-dc_ca1);
        double Q_sei2 = H_SEI * m * (-dc_sei2);
        double Q_an2  = H_an  * m * (-dc_an2);
        double Q_ca2  = H_ca  * m * (-dc_ca2);

        // Heat loss
        double Q_loss1 = h * A_s * (T1 - T_amb);
        double Q_loss2 = h * A_s * (T2 - T_amb);

        // Temperature rates
        double thermal_mass = m * Cp;
        double dT1_dt = (Q_sei1 + Q_an1 + Q_ca1 - Q_loss1) / thermal_mass;
        double dT2_dt = (Q_sei2 + Q_an2 + Q_ca2 - Q_loss2) / thermal_mass;

        // Euler update
        State ns;
        ns[T1_IDX] = std::clamp(T1 + dt * dT1_dt, T_MIN, T_MAX);
        ns[T2_IDX] = std::clamp(T2 + dt * dT2_dt, T_MIN, T_MAX);
        ns[C_SEI1] = std::clamp(c_sei1 + dt * dc_sei1, 0.0, 1.0);
        ns[C_SEI2] = std::clamp(c_sei2 + dt * dc_sei2, 0.0, 1.0);
        ns[C_AN1]  = std::clamp(c_an1  + dt * dc_an1,  0.0, 1.0);
        ns[C_AN2]  = std::clamp(c_an2  + dt * dc_an2,  0.0, 1.0);
        ns[C_CA1]  = std::clamp(c_ca1  + dt * dc_ca1,  0.0, 1.0);
        ns[C_CA2]  = std::clamp(c_ca2  + dt * dc_ca2,  0.0, 1.0);
        return ns;
    }

private:
    static constexpr int T1_IDX = 0;
    static constexpr int T2_IDX = 1;
};

} // namespace kernel
} // namespace probos
