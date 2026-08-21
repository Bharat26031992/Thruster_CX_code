function result = max_voltage_molybdenum_grid(gap_mm, surface_condition, safety_margin)
% MAX_VOLTAGE_MOLYBDENUM_GRID
% Calcola la massima differenza di potenziale tra griglie di molibdeno
% prima del breakdown/arco elettrico, usando campi di breakdown sperimentali.
%
% INPUT:
%   gap_mm            - gap tra le griglie [mm]
%   surface_condition - 'polished', 'grit_blasted', 'grid_material', 'conditioned'
%   safety_margin     - fattore di margine (es. 0.7)
%
% OUTPUT:
%   result - struct con:
%       .V_max                 [V]
%       .E_operativo_MVm       [MV/m]
%       .E_breakdown_MVm       [MV/m]
%       .surface_condition
%       .condition_description
%       .recommendation
%       .gap_mm
%
% NOTE:
% Valori di E_breakdown derivati da risultati sperimentali su ottiche in Mo:
% - polished      ~ 8  MV/m
% - grit_blasted  ~ 10 MV/m
% - grid_material ~ 11 MV/m
% - conditioned   ~ 15 MV/m
%
% Uso:
%   r = max_voltage_molybdenum_grid(0.3, 'conditioned', 0.7)
%   fprintf('Vmax = %.0f V\n', r.V_max)

    if nargin < 2 || isempty(surface_condition)
        surface_condition = 'conditioned';
    end
    if nargin < 3 || isempty(safety_margin)
        safety_margin = 0.7;
    end

    if gap_mm <= 0
        error('gap_mm deve essere positivo.');
    end
    if safety_margin < 0.3 || safety_margin > 1.5
        error('safety_margin deve essere compreso tra 0.3 e 1.5.');
    end

    switch lower(surface_condition)
        case 'polished'
            E_breakdown = 8.0;
            condition_description = 'Mo lucidata, non condizionata - breakdown basso (~8 MV/m)';
            recommendation = 'Superficie non ideale per alta tensione. Conditioning consigliato.';
        case 'grit_blasted'
            E_breakdown = 10.0;
            condition_description = 'Mo sabbiata - breakdown medio (~10 MV/m)';
            recommendation = 'Buona per design. Il conditioning puo migliorare il breakdown.';
        case 'grid_material'
            E_breakdown = 11.0;
            condition_description = 'Mo griglia reale con fori - breakdown ~11 MV/m';
            recommendation = 'Caso realistico per griglie prodotte. Usa safety_margin >= 0.6.';
        case 'conditioned'
            E_breakdown = 15.0;
            condition_description = 'Mo condizionata dopo archi di conditioning - breakdown ~15 MV/m';
            recommendation = 'Condizione ottimale. safety_margin 0.6-0.7 consigliato.';
        otherwise
            error('surface_condition non valida. Usa: polished, grit_blasted, grid_material, conditioned');
    end

    E_operativo = E_breakdown * safety_margin;
    gap_m = gap_mm * 1e-3;
    V_max = E_operativo * 1e6 * gap_m;

    if safety_margin < 0.6
        recommendation = [recommendation, ' Attenzione: per lunga vita operativa usa >= 0.65.'];
    end

    result = struct();
    result.V_max = V_max;
    result.E_operativo_MVm = E_operativo;
    result.E_breakdown_MVm = E_breakdown;
    result.surface_condition = lower(surface_condition);
    result.condition_description = condition_description;
    result.recommendation = recommendation;
    result.gap_mm = gap_mm;
end
