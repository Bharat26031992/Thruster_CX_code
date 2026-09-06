% ESEMPIO DI USO
r = max_voltage_molybdenum_grid(0.65, 'polished', 0.4);

fprintf('Gap = %.3f mm\n', r.gap_mm);
fprintf('Condizione = %s\n', r.surface_condition);
fprintf('E_breakdown = %.2f MV/m\n', r.E_breakdown_MVm);
fprintf('E_operativo = %.2f MV/m\n', r.E_operativo_MVm);
fprintf('V_max = %.0f V (%.2f kV)\n', r.V_max, r.V_max/1000);
fprintf('Note: %s\n', r.recommendation);
