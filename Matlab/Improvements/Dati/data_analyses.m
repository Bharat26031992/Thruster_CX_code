S = load('divergence_data.mat');
figure(1);
plot(S.iter_history_out, S.div_history_deg, 'LineWidth', 1.5);
grid on;
xlabel('Iteration');
ylabel('95th percentile half-angle [deg]');


S2 = load('exit_energy_data.mat');
A = S2.axialEnergySnapshotsOut{end};

figure;
yyaxis left
plot(A.binCentersXmm, A.meanEnergyeV, 'b-', 'LineWidth', 2);
ylabel('Mean primary ion energy [eV]');

yyaxis right
plot(A.binCentersXmm, A.meanEmagVpm, 'r--', 'LineWidth', 2);
ylabel('|E| [V/m]');

xlabel('Axial position x [mm]');
title('Primary ion axial acceleration diagnostic');
grid on;