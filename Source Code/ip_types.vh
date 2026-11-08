// Filename: ip_types.vh
// Authors: Aaron Grossman; Project contributors; see Git history.
// Date: 2026-11-08
// General Description: Names project-wide elaboration-time implementation backends.
// AI Disclosure: Codex assisted with coding and verification.
`ifndef PROJECT_IP_TYPES_VH
`define PROJECT_IP_TYPES_VH
`define IP_GENERIC 0
`define IP_ALTERA 1
// Reserved project identity: wrappers reject it until implemented and validated.
`define IP_XILINX 2
// IP_TYPE is selected at the project/top level and passed to technology wrappers.
// Individual wrappers must reject backends they do not implement.
// No wrapper may substitute Generic for an unsupported identity.
`endif
