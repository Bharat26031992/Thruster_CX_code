S = load('divergence_data.mat');
plot(S.iter_history_out, S.div_history_deg, 'LineWidth', 1.5);
grid on;
xlabel('Iteration');
ylabel('95th percentile half-angle [deg]');