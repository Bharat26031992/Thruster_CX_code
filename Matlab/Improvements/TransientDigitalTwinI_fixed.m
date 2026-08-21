function TransientDigitalTwinI()
% Main application entry point.
% Builds the GUI, initializes simulation state, and runs the live event loop
% for ion extraction, sputtering damage, telemetry, and optional 3D display.

% --- 1. GLOBAL STATE & SIMULATION VARIABLES ---
sim.isRunning = false;
sim.dt        = 8e-11;
sim.q         = 1.602e-19;
sim.m_XE      = 131.293 * 1.6605e-27;
sim.kB        = 1.380649e-23;

% Vectorized particle arrays
p_x = []; p_y = []; p_vx = []; p_vy = []; p_isCEX = false(0,1);

% Mesh, field, and damage variables
X = []; Y = []; V = []; Ex = []; Ey = [];
isBound = []; V_fixed = []; damage_map = [];
Lx = 5; Ly = 3; dx = 0.006; dy = 0.006;

primaryHitCountGrid2 = 0;
primaryHitCountGrid3 = 0;
gridXStart = [];
gridXEnd = [];

sim.isSweepRunning = false;
sim.stopSweepRequested = false;
lbl_sweepStatus = [];

% Telemetry and 3D objects
iter_history = []; ebs_history = []; div_history = [];
mean_exit_ke_history = []; mean_exit_velocity_history = [];
divergence_snapshots = {}; energy_snapshots  = {}; recorded_frames = {};

f3d = []; ax3d = []; h_surf3d = []; h_prim3d = []; h_cex3d = [];

% Grid stack definition and dynamic GUI handles
grid_defs = struct('name', {}, 'voltage', {}, 'thickness', {}, ...
    'holeRadius', {}, 'chamfer', {}, 'gapAfter', {});
grid_ui = struct('panel', {}, 'name', {}, 'voltage', {}, ...
    'thickness', {}, 'holeRadius', {}, 'chamfer', {}, 'gapAfter', {});
gridScroll = []; gridContainer = [];
sweepFig = [];
sweepUI = struct();
sweepConfig = struct( ...
    'parameter', 'Chamfer', ...
    'minVal', 0, ...
    'maxVal', -15, ...
    'time_s', 1e-7, ...
    'points', 10);

sweepResults = struct([]);

% --- 2. SETUP THE GUI ---
fig = uifigure( ...
    'Name', '2-Grid Digital Twin: Morphing, Telemetry & LIVE 3D', ...
    'Position', [20, 30, 1280, 780], 'Color', '#F4F6F9','CloseRequestFcn', @onClose);

% --- TOP MENU: OPTIONS ---
menu_options = uimenu(fig, 'Text', 'Options');

menu_save_png = uimenu(menu_options, ...
    'Text', 'Save as PNG', ...
    'MenuSelectedFcn', @onSaveAsPng);

menu_sweep = uimenu(menu_options, ...
    'Text', 'Sweep', ...
    'MenuSelectedFcn', @onSweep);

pnl = uipanel(fig, 'Position', [10, 10, 300, 760], 'BackgroundColor', '#FFFFFF');
sputterMap = [
    linspace(1.00, 0.95, 256)', ...  % R
    linspace(1.00, 0.25, 256)', ...  % G
    linspace(0.60, 0.00, 256)'  ...  % B
];
% --- 2A. GRID STACK GUI ---
uilabel(pnl, 'Text', '1. GRID STACK', 'Position', [10, 730, 280, 22], ...
    'FontWeight', 'bold', 'FontColor', [0.1 0.3 0.6]);

btn_addGrid = uibutton(pnl, ...
    'Text', 'ADD GRID', 'Position', [10, 695, 135, 30], ...
    'BackgroundColor', [0.80 0.92 1.00], 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @addGrid);

btn_removeGrid = uibutton(pnl, ...
    'Text', 'REMOVE LAST GRID', 'Position', [155, 695, 135, 30], ...
    'BackgroundColor', [1.00 0.88 0.88], 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @removeLastGrid);

gridScroll = uipanel(pnl, ...
    'Position', [10, 295, 280, 385], 'BackgroundColor', [0.98 0.98 0.99], ...
    'Title', 'Grid Parameters');

gridContainer = uipanel(gridScroll, 'Position', [0, 0, 260, 385], ...
    'BackgroundColor', [0.98 0.98 0.99], 'BorderType', 'none');

% --- 2B. PLASMA & MORPHING (SCROLLABLE) ---
uilabel(pnl, 'Text', '2. PLASMA & MORPHING', 'Position', [10, 265, 280, 22], ...
    'FontWeight', 'bold', 'FontColor', [0.1 0.3 0.6]);

plasmaScroll = uipanel(pnl, 'Position', [10, 10, 280, 250], ...
    'BackgroundColor', [0.98 0.98 0.99], 'Title', 'Plasma / Controls', ...
    'Scrollable', 'on');

plasmaContainer = uipanel(plasmaScroll, 'Position', [0, 0, 260, 500], ...
    'BackgroundColor', [0.98 0.98 0.99], 'BorderType', 'none');

%% --- Initial conditions
y0     = 420;  drow   = 28;   labelX = 10;  fieldX = 150;
labelW = 130;  fieldW = 100;  rowH   = 22;

uilabel(plasmaContainer, 'Text', 'Ion Temp (eV):', 'Position', [labelX, y0, labelW, rowH], ...
    'FontColor', 'b');

ui_Ti = uieditfield(plasmaContainer, 'numeric','Position', [fieldX, y0, fieldW, rowH], ...
    'Value', 0.034);

uilabel(plasmaContainer, 'Text', 'Electron Temp (eV):', 'Position', [labelX, y0-drow, labelW, rowH], ...
    'FontColor', [0 0 0.8]);

ui_Te = uieditfield(plasmaContainer, 'numeric', 'Position', [fieldX, y0-drow, fieldW, rowH], ...
    'Value', 7.85);

uilabel(plasmaContainer, 'Text', 'Neutral Temp (K):','Position', [labelX, y0-2*drow, labelW, rowH], ...
    'FontColor', '#D95319');

ui_Tn = uieditfield(plasmaContainer, 'numeric', 'Position', ...
    [fieldX, y0-2*drow, fieldW, rowH], 'Value', 400);

uilabel(plasmaContainer, 'Text', 'Electron Dens ne:', 'Position', ...
    [labelX, y0-3*drow, labelW, rowH], 'FontColor', [0 0 0.8]);

ui_ne = uieditfield(plasmaContainer, 'numeric', 'Position',...
    [fieldX, y0-3*drow, fieldW, rowH], 'Value', 8e17);

uilabel(plasmaContainer, 'Text', 'Neutral Dens n0:','Position', [labelX, y0-4*drow, labelW, rowH]);
ui_n0 = uieditfield(plasmaContainer, 'numeric', 'Position', ...
    [fieldX, y0-4*drow, fieldW, rowH], 'Value', 5.89e18);

uilabel(plasmaContainer, 'Text', 'Accel. Factor (X):', 'Position', ...
    [labelX, y0-5*drow, labelW, rowH], 'FontColor', 'r');

ui_Accel = uieditfield(plasmaContainer, 'numeric', 'Position', ...
    [fieldX, y0-5*drow, fieldW, rowH], 'Value', 5e13);

uilabel(plasmaContainer, 'Text', 'Cell Fail Thresh:', 'Position',...
    [labelX, y0-6*drow, labelW, rowH], 'FontColor', 'r');

ui_Thresh = uieditfield(plasmaContainer, 'numeric', 'Position',...
    [fieldX, y0-6*drow, fieldW, rowH], 'Value', 1.0);

btn_recalc = uibutton(plasmaContainer, 'Text', '1. BUILD DOMAIN', ...
    'Position', [10, 185, 240, 26],'BackgroundColor', [1 0.9 0.6], ...
    'FontWeight', 'bold', 'ButtonPushedFcn', @buildDomain);

txt_status = uilabel(plasmaContainer, 'Text', 'Status: Ready.', ...
    'Position', [10, 148, 240, 18],'FontSize', 10,'FontWeight', 'bold', ...
    'FontColor', [0 0.5 0]);

lbl_sweepStatus = uilabel(plasmaContainer, ...
    'Text', 'Sweep: idle', ...
    'Position', [10, 130, 240, 18], ...
    'FontSize', 10, ...
    'FontWeight', 'bold', ...
    'FontColor', [0.1 0.1 0.7]);

btn_toggle = uibutton(plasmaContainer, 'Text', '2. START BEAM EXTRACTION', ...
    'Position', [10, 150, 240, 26], 'BackgroundColor', [0.8 1 0.8], ...
    'FontWeight', 'bold', 'ButtonPushedFcn', @toggleSim);

btn_3d = uibutton(plasmaContainer, 'Text', 'OPEN LIVE 3D CAD VIEW', ...
    'Position', [10, 116, 240, 26], 'BackgroundColor', '#E0F7FA', ...
    'FontWeight', 'bold', 'ButtonPushedFcn', @init3D);

btn_saveDiv = uibutton(plasmaContainer, 'Text', 'Save Divergence .mat', ...
    'Position', [10, 82, 240, 26], 'BackgroundColor', [0.85 0.92 1.0], ...
    'ButtonPushedFcn', @saveDivergenceData);

btn_saveVel = uibutton(plasmaContainer, 'Text', 'Extract Exit Energy .mat', ...
'Position', [10, 48, 240, 26], 'BackgroundColor', [0.85 1.00 0.85], ...
'ButtonPushedFcn', @saveVelocityData);

chk_recordGif = uicheckbox(plasmaContainer, 'Text', 'Record Frames (0)', ...
    'Position', [10, 54, 160, 22], 'FontWeight', 'bold', 'FontColor', 'r');

chk_recordGif = uicheckbox(plasmaContainer, 'Text', 'Record Frames (0)', ...
'Position', [10, 24, 160, 22], 'FontWeight', 'bold', 'FontColor', 'r');

btn_saveGif = uibutton(plasmaContainer, 'Text', 'Save GIF Animation', ...
'Position', [10, 0, 240, 22], 'BackgroundColor', [0.9 0.8 1], ...
'ButtonPushedFcn', @saveGif);

chk_erosion = uicheckbox(plasmaContainer, 'Text', 'Enable erosion simulation', ...
'Position', [10, 78, 180, 22], 'Value', true, 'FontWeight', 'bold', ...
'FontColor', [0.6 0 0]);

%% --- Default two-grid configuration
grid_defs(1) = struct('name', 'Screen', 'voltage', 1300, 'thickness', 1.2, ...
    'holeRadius', 1.342, 'chamfer', -20, 'gapAfter', 0.8);
grid_defs(2) = struct('name', 'Accel', 'voltage', -200, 'thickness', 0.5, ...
    'holeRadius', 0.823, 'chamfer', 0, 'gapAfter', 0.5);
grid_defs(3) = struct('name', 'Accel', 'voltage', 50, 'thickness', 0.5, ...
    'holeRadius', 1.3, 'chamfer', 0, 'gapAfter', 0.0);
rebuildGridUI();

%% --- RIGHT PANEL: AXES LAYOUT ---
ax_live = uiaxes(fig, 'Position', [320, 380, 940, 390]);
title(ax_live, 'Live Axisymmetric Plasma Extraction & E-Field');
xlabel(ax_live, 'Axial Position X (mm)');
ylabel(ax_live, 'Radial Position Y (mm)');
hold(ax_live, 'on');
box(ax_live, 'on');
axis(ax_live, 'equal');
xlim(ax_live, [0, Lx]);
ylim(ax_live, [0, Ly]);

ax_live.Color  = [0.97 0.98 1.00];
ax_live.XColor = [0.15 0.15 0.15];
ax_live.YColor = [0.15 0.15 0.15];

%% -------- Creating the side bar with energy ---------
energy_max_eV = max([grid_defs.voltage]) + 200;
energy_max_eV = max(energy_max_eV, 1);

blueRedMap = [linspace(0,1,256)', zeros(256,1), linspace(1,0,256)'];
colormap(ax_live, blueRedMap);
clim(ax_live, [0 energy_max_eV]);

h_beam = scatter(ax_live, NaN, NaN, 8, NaN, 'filled', ...
    'MarkerFaceAlpha', 0.85, 'MarkerEdgeColor', 'none');
h_cex = scatter(ax_live, NaN, NaN, 10, NaN, 'filled', ...
    'MarkerFaceAlpha', 0.85, 'MarkerEdgeColor', 'none');

cb_energy = colorbar(ax_live, 'eastoutside');
cb_energy.Label.String = 'Ion kinetic energy [eV]';
cb_energy.Color = [0.1 0.1 0.1];

%% -------

ax_damage = uiaxes(fig, 'Position', [320, 10, 300, 320]);
title(ax_damage, 'Live Sputter Damage Map');
xlabel(ax_damage, 'Axial X (mm)');
ylabel(ax_damage, 'Radial Y (mm)');
hold(ax_damage, 'on'); box(ax_damage, 'on');
colormap(ax_damage, flipud(hot(256)));

ax_ebs = uiaxes(fig, 'Position', [640, 10, 300, 320]);
title(ax_ebs, 'Electron Backstreaming (EBS)');
xlabel(ax_ebs, 'Iteration');
ylabel(ax_ebs, 'Min Centerline Volts (V)');
hold(ax_ebs, 'on'); grid(ax_ebs, 'on');
h_ebs = plot(ax_ebs, NaN, NaN, 'm-', 'LineWidth', 2);
yline(ax_ebs, -20, 'r--', 'EBS Failure Limit (-20V)', 'LabelHorizontalAlignment', 'left');

ax_div = uiaxes(fig, 'Position', [960, 10, 300, 320]);
title(ax_div, 'Primary Beam 95% Divergence');
xlabel(ax_div, 'Iteration');
ylabel(ax_div, 'Half-Angle (Deg)');
hold(ax_div, 'on'); grid(ax_div, 'on');
h_div = plot(ax_div, NaN, NaN, 'b-', 'LineWidth', 2);

%% --- 3. MAIN SIMULATION LOOP ---
iteration = 0;

while ishandle(fig)
    if sim.isRunning && ~isempty(Ex)
        doOneSimulationStep();
    else
        pause(0.1);
    end
end

function doOneSimulationStep()
    iteration = iteration + 1;

    sourceRadius = max(0.15, grid_defs(1).holeRadius - 0.1);

    yMinInject = 0.05;
    nCellsInject = max(1, ceil((sourceRadius - yMinInject) / dy));
    minParticlesPerCell = 4;

    numInjectBase = 30;
    num_inject = max(numInjectBase, minParticlesPerCell * nCellsInject);

    new_y = linspace(yMinInject, sourceRadius, num_inject)' + (rand(num_inject,1)-0.5)*0.05;
    new_y = min(max(new_y, yMinInject), sourceRadius);
    new_x = repmat(0.1, num_inject, 1);

    v_bohm = sqrt(2 * sim.q * 0.034 / sim.m_XE);
    v_spread = sqrt(sim.q * ui_Ti.Value / sim.m_XE);

    p_x = [p_x; new_x];
    p_y = [p_y; new_y];
    p_vx = [p_vx; repmat(v_bohm, num_inject, 1) + randn(num_inject,1)*v_spread];
    p_vy = [p_vy; randn(num_inject,1)*v_spread];
    p_isCEX = [p_isCEX; false(num_inject, 1)];

    Ex_p = interp2(X, Y, Ex, p_x, p_y, 'linear', 0);
    Ey_p = interp2(X, Y, Ey, p_x, p_y, 'linear', 0);

    p_vx = p_vx + (sim.q / sim.m_XE) .* Ex_p .* sim.dt;
    p_vy = p_vy + (sim.q / sim.m_XE) .* Ey_p .* sim.dt;
    p_x = p_x + p_vx .* sim.dt .* 1000;
    p_y = p_y + p_vy .* sim.dt .* 1000;

    dl_min_m = min(dx, dy) * 1e-3;

    if ~isempty(p_vx)
        vmag_all = sqrt(p_vx.^2 + p_vy.^2);
        vmax_now = max(vmag_all);
        step_ratio = vmax_now * sim.dt / dl_min_m;

        if step_ratio >= 1.0
            sim.isRunning = false;
            btn_toggle.Text = '2. RESUME BEAM EXTRACTION';
            btn_toggle.BackgroundColor = [0.8 1 0.8];

            msg = sprintf(['Particle step condition violated during run.\n' ...
                'Require vmax * dt < Dl_min everywhere.\n' ...
                'Current vmax = %.3e m/s\n' ...
                'dt = %.3e s\n' ...
                'Dl_min = %.3e m\n' ...
                'vmax*dt/Dl_min = %.3f\n' ...
                'Simulation paused. Reduce dt or coarsen the mesh.'], ...
                vmax_now, sim.dt, dl_min_m, step_ratio);

            uialert(fig, msg, 'Particle Time-Step Warning');
            txt_status.Text = sprintf('Status: particle step violation (ratio = %.3f).', step_ratio);
            drawnow;
            return;
        end
    end

    max_grid_x = getLastGridExit();
    post_grid_mask = (~p_isCEX) & (p_x > max_grid_x) & (p_vx > 0);

    angles = [];
    mean_exit_ke_eV = NaN;
    mean_exit_velocity_mps = NaN;
    
    if sum(post_grid_mask) > 5
        vx_exit = p_vx(post_grid_mask);
        vy_exit = p_vy(post_grid_mask);
    
        angles = abs(atan2(vy_exit, vx_exit)) * 180/pi;
    
        v_exit_mag = sqrt(vx_exit.^2 + vy_exit.^2);
        ke_exit_eV = 0.5 * sim.m_XE * v_exit_mag.^2 / sim.q;
    
        current_div = prctile(angles, 95);
        mean_exit_ke_eV = mean(ke_exit_eV);
        mean_exit_velocity_mps = mean(v_exit_mag);
    else
        current_div = NaN;
    end
    min_pot = min(V(1, :));

    hit_grid = interp2(X, Y, double(isBound), p_x, p_y, 'nearest', 1) == 1;
    primary_hit_mask = hit_grid & (~p_isCEX);

    primary_hit_mask = hit_grid & (~p_isCEX);

    if any(primary_hit_mask)
        pxh = p_x(primary_hit_mask);
        pyh = p_y(primary_hit_mask);
    
        if numel(grid_defs) >= 2
            x2s = gridXStart(2);
            x2e = gridXEnd(2);
            R2 = grid_defs(2).holeRadius + max(0, (pxh - x2s)) * tand(grid_defs(2).chamfer);
            hit2 = (pxh >= x2s) & (pxh <= x2e) & (pyh >= R2);
            primaryHitCountGrid2 = primaryHitCountGrid2 + sum(hit2);
        end
    
        if numel(grid_defs) >= 3
            x3s = gridXStart(3);
            x3e = gridXEnd(3);
            R3 = grid_defs(3).holeRadius + max(0, (pxh - x3s)) * tand(grid_defs(3).chamfer);
            hit3 = (pxh >= x3s) & (pxh <= x3e) & (pyh >= R3);
            primaryHitCountGrid3 = primaryHitCountGrid3 + sum(hit3);
        end
    end
    out_of_bounds = p_x < 0 | p_x > Lx | p_y < 0 | p_y > Ly | isnan(p_x);

    if chk_erosion.Value
        is_cex_hit = hit_grid & p_isCEX;

        if any(is_cex_hit)
            hx = p_x(is_cex_hit);
            hy = p_y(is_cex_hit);
            hvx = p_vx(is_cex_hit);
            hvy = p_vy(is_cex_hit);

            ix = min(size(X,2), max(1, round(hx / dx) + 1));
            iy = min(size(Y,1), max(1, round(hy / dy) + 1));

            v_mag_sq = hvx.^2 + hvy.^2;
            E_eV = (0.5 * sim.m_XE * v_mag_sq) / sim.q;

            Y_yield = zeros(size(E_eV));
            valid_E = E_eV > 30;
            Y_yield(valid_E) = 1.05e-4 .* (E_eV(valid_E) - 30).^1.5;

            cell_area_mm2 = dx * dy;
            damage_added = accumarray([iy, ix], ...
                (Y_yield .* ui_Accel.Value) ./ cell_area_mm2, ...
                size(damage_map));

            damage_map = damage_map + damage_added;

            broken_cells = (damage_map > ui_Thresh.Value) & isBound;
            if any(broken_cells, 'all')
                isBound(broken_cells) = false;
                damage_map(broken_cells) = 0;
                txt_status.Text = 'Status: Cell failed. Remeshing Laplace...';
                drawnow;
                recalcLaplace();
                update3DSurface();
            end
        end
    else
        is_cex_hit = hit_grid & p_isCEX;
        if any(is_cex_hit)
            hx = p_x(is_cex_hit);
            hy = p_y(is_cex_hit);
            ix = min(size(X,2), max(1, round(hx / dx) + 1));
            iy = min(size(Y,1), max(1, round(hy / dy) + 1));
            hit_added = accumarray([iy, ix], 1, size(damage_map));
            damage_map = damage_map + hit_added;
        end
    end

    p_x = p_x(:); p_y = p_y(:); p_vx = p_vx(:); p_vy = p_vy(:); p_isCEX = p_isCEX(:);
    hit_grid = hit_grid(:); out_of_bounds = out_of_bounds(:);

    dead_mask = hit_grid | out_of_bounds;
    keep_mask = ~dead_mask;

    p_x = p_x(keep_mask);
    p_y = p_y(keep_mask);
    p_vx = p_vx(keep_mask);
    p_vy = p_vy(keep_mask);
    p_isCEX = p_isCEX(keep_mask);

    primary_mask = ~p_isCEX & (p_x > 0.2);
    if any(primary_mask)
        v_mag = sqrt(p_vx(primary_mask).^2 + p_vy(primary_mask).^2);
        g = max(v_mag, 1);
        sigma = ((-0.8821 .* log(g) + 15.1262).^2) .* 1e-20;
        prob = 1 - exp(-ui_n0.Value .* sigma .* g .* sim.dt);
        collided = rand(sum(primary_mask), 1) < prob;
        if any(collided)
            idx = find(primary_mask);
            c_idx = idx(collided);
            num_cex = length(c_idx);
            neut_vth = sqrt(2 * sim.kB * ui_Tn.Value / sim.m_XE);
            p_vx(c_idx) = randn(num_cex,1) .* neut_vth;
            p_vy(c_idx) = randn(num_cex,1) .* neut_vth;
            p_isCEX(c_idx) = true;
        end
    end

    if mod(iteration, 5) == 0
            updateSimulationPlots(min_pot, current_div, angles, post_grid_mask, ...
        mean_exit_ke_eV, mean_exit_velocity_mps);
    end
end

function updateSimulationPlots(min_pot, current_div, angles, post_grid_mask, ...
    mean_exit_ke_eV, mean_exit_velocity_mps)

    beam_mask = ~p_isCEX;
    cex_mask = p_isCEX;

    KE_eV = 0.5 * sim.m_XE * (p_vx.^2 + p_vy.^2) / sim.q;
    KE_eV = max(KE_eV, 0);

    if any(beam_mask)
        set(h_beam, 'XData', p_x(beam_mask), 'YData', p_y(beam_mask), 'CData', KE_eV(beam_mask));
    else
        set(h_beam, 'XData', NaN, 'YData', NaN, 'CData', NaN);
    end

    if any(cex_mask)
        set(h_cex, 'XData', p_x(cex_mask), 'YData', p_y(cex_mask));
    else
        set(h_cex, 'XData', NaN, 'YData', NaN);
    end

    iter_history = [iter_history, iteration];
    ebs_history = [ebs_history, min_pot];
    div_history = [div_history, current_div];
    mean_exit_ke_history = [mean_exit_ke_history, mean_exit_ke_eV];
    mean_exit_velocity_history = [mean_exit_velocity_history, mean_exit_velocity_mps];
    
    energy_snapshot = struct();
    energy_snapshot.iteration = iteration;
    energy_snapshot.mean_exit_energy_eV = mean_exit_ke_eV;
    energy_snapshot.num_post_grid = sum(post_grid_mask);
    
    energy_snapshots {end+1} = energy_snapshot;

    snapshot = struct();
    snapshot.iteration = iteration;
    snapshot.current_div_deg = current_div;
    snapshot.primary_angles_deg = angles;
    snapshot.num_post_grid = sum(post_grid_mask);
    divergence_snapshots{end+1} = snapshot;

    set(h_ebs, 'XData', iter_history, 'YData', ebs_history);
    set(h_div, 'XData', iter_history, 'YData', div_history);
    xlim(ax_ebs, [max(0, iteration-400), max(100, iteration)]);
    xlim(ax_div, [max(0, iteration-400), max(100, iteration)]);

    cla(ax_damage);
    hold(ax_damage, 'on');
    box(ax_damage, 'on');

    if ~chk_erosion.Value
        damage_plot = NaN(size(damage_map));
        visual_mask = isBound & (damage_map > 0);
        damage_plot(visual_mask) = damage_map(visual_mask);

        if any(visual_mask, 'all')
            imagesc(ax_damage, [0 Lx], [0 Ly], damage_plot);
            set(ax_damage, 'YDir', 'normal');
            colormap(ax_damage, sputterMap);
            clim(ax_damage, [0 max(damage_map(visual_mask)) + eps]);
        else
            text(ax_damage, 0.5, 0.5, 'No CEX wall hits yet', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', 'Color', [0.3 0.3 0.3]);
        end

        [gy, gx] = find(isBound);
        scatter(ax_damage, (gx-1)*dx, (gy-1)*dy, 2, [0.25 0.25 0.25], ...
            'filled', 'MarkerFaceAlpha', 0.25);
    else
        if isempty(damage_map) || all(~isfinite(damage_map(:)))
            text(ax_damage, 0.5, 0.5, 'No damage data', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', 'Color', [0.3 0.3 0.3]);
        else
            dmin = min(damage_map(:));
            dmax = max(damage_map(:));
            if dmax > dmin
                contourf(ax_damage, X, Y, damage_map, 15, 'LineStyle', 'none');
            else
                imagesc(ax_damage, [0 Lx], [0 Ly], damage_map);
                set(ax_damage, 'YDir', 'normal');
            end
        end

        colormap(ax_damage, flipud(hot(256)));

        [gy, gx] = find(isBound);
        scatter(ax_damage, (gx-1)*dx, (gy-1)*dy, 2, [0.3 0.3 0.3], ...
            'filled', 'MarkerFaceAlpha', 0.5);
    end

    xlim(ax_damage, [0.5, Lx]);
    ylim(ax_damage, [0, Ly]);
    xlabel(ax_damage, 'Axial X (mm)');
    ylabel(ax_damage, 'Radial Y (mm)');
    title(ax_damage, 'Live Sputter Damage Map');

    if ~isempty(f3d) && isvalid(f3d)
        prim_mask = ~p_isCEX;
        if any(prim_mask)
            th_p = rand(sum(prim_mask), 1) * 2 * pi;
            set(h_prim3d, 'XData', p_x(prim_mask), ...
                'YData', p_y(prim_mask).*cos(th_p), ...
                'ZData', p_y(prim_mask).*sin(th_p));
        else
            set(h_prim3d, 'XData', NaN, 'YData', NaN, 'ZData', NaN);
        end

        cex_mask = p_isCEX;
        if any(cex_mask)
            th_c = rand(sum(cex_mask), 1) * 2 * pi;
            set(h_cex3d, 'XData', p_x(cex_mask), ...
                'YData', p_y(cex_mask).*cos(th_c), ...
                'ZData', p_y(cex_mask).*sin(th_c));
        else
            set(h_cex3d, 'XData', NaN, 'YData', NaN, 'ZData', NaN);
        end

        if mod(iteration, 20) == 0
            update3DSurfaceColor();
        end
    end

    if chk_recordGif.Value
        recorded_frames{end+1} = getframe(fig);
        chk_recordGif.Text = sprintf('Record Frames (%d)', length(recorded_frames));
    end

    txt_status.Text = sprintf('Status: Active Particles: %d | Iteration: %d', length(p_x), iteration);
    drawnow;
end

    function runSingleSimulationForIterations(nSteps, iRun, nRuns)
    sim.isRunning = true;

    for iStep = 1:nSteps
        if ~ishandle(fig) || isempty(Ex)
            break;
        end

        if sim.stopSweepRequested
            break;
        end

        if ~sim.isRunning
            break;
        end

        doOneSimulationStep();

        if mod(iStep, 20) == 0 || iStep == 1 || iStep == nSteps
            lbl_sweepStatus.Text = sprintf( ...
                'Sweep: run %d/%d | internal iter %d/%d', ...
                iRun, nRuns, iStep, nSteps);
            drawnow;
        end
    end

    if isempty(iter_history)
         recordTelemetrySnapshot();
    end
    sim.isRunning = false;
end

function saveSweepResults()
    if isempty(sweepResults)
        uialert(fig, 'No sweep results available.', 'Warning');
        return;
    end

    [filename, pathname] = uiputfile('*.mat', 'Save Sweep Results', 'sweep_results.mat');
    if isequal(filename,0)
        return;
    end

    sweepConfig_out = sweepConfig;
    sweepResults_out = sweepResults;
    save(fullfile(pathname, filename), 'sweepConfig_out', 'sweepResults_out');
    uialert(fig, 'Sweep results saved successfully.', 'Success');
end

    function toggleSim(~, ~)
    % If a sweep is running, this button acts as STOP SWEEP
    if sim.isSweepRunning
        sim.stopSweepRequested = true;
        btn_toggle.Text = 'Stopping sweep...';
        btn_toggle.BackgroundColor = [1 0.2 0.2];
        txt_status.Text = 'Status: stop requested for sweep.';
        lbl_sweepStatus.Text = 'Sweep: stop requested...';
        drawnow;
        return;
    end

    % Normal beam extraction behavior
    if isempty(Ex)
        uialert(fig, 'Build Domain first!', 'Warning');
        return;
    end

    sim.isRunning = ~sim.isRunning;
    if sim.isRunning
        btn_toggle.Text = '2. PAUSE BEAM EXTRACTION';
        btn_toggle.BackgroundColor = [1 0.8 0.8];
    else
        btn_toggle.Text = '2. RESUME BEAM EXTRACTION';
        btn_toggle.BackgroundColor = [0.8 1 0.8];
    end
end

function addGrid(~, ~)
% Adds a new grid definition to the stack using default values.
% The GUI is then rebuilt so the new editable parameter block appears.
    syncGridDefsFromUI();
    newIdx = numel(grid_defs) + 1;
    grid_defs(newIdx) = struct('name', sprintf('Grid%d', newIdx), ...
        'voltage', 50, 'thickness', 1.0, 'holeRadius', 0.7, ...
        'chamfer', 0.0, 'gapAfter', 0.5);
    rebuildGridUI();
end

function removeLastGrid(~, ~)
% Removes the last grid in the current stack.
% At least one grid is always kept to avoid an invalid domain.
    syncGridDefsFromUI();
    if numel(grid_defs) <= 1
        uialert(fig, 'At least one grid must remain.', 'Warning');
        return;
    end
    grid_defs(end) = [];
    rebuildGridUI();
end

function syncGridDefsFromUI()
% Copies the values currently typed in the dynamic grid panels into the
% grid_defs structure used by the solver and geometry builder.
    for k = 1:numel(grid_ui)
        grid_defs(k).name = grid_ui(k).name.Value;
        grid_defs(k).voltage = grid_ui(k).voltage.Value;
        grid_defs(k).thickness = grid_ui(k).thickness.Value;
        grid_defs(k).holeRadius = grid_ui(k).holeRadius.Value;
        grid_defs(k).chamfer = grid_ui(k).chamfer.Value;
        grid_defs(k).gapAfter = grid_ui(k).gapAfter.Value;
    end
end

function buildDomain(~, ~)
% Builds the 2D axisymmetric electrostatic domain from the current grid
% stack, resets simulation state, and solves the initial Laplace field.
    sim.isRunning = false;
    btn_toggle.Text = '2. START BEAM EXTRACTION';
    btn_toggle.BackgroundColor = [0.8 1 0.8];

    syncGridDefsFromUI();

    energy_max_eV = max([grid_defs.voltage]) + 200;
    energy_max_eV = max(energy_max_eV, 1);
    clim(ax_live, [0 energy_max_eV]);

    % Checking where the debye length is ok
    [is_ok_debye, lambdaD_mm, target_mm] = checkDebyeResolution(ui_Te.Value, ui_ne.Value, 0.5);
    % Check timestep against electron plasma frequency
    [is_ok_plasma_dt, omega_pe, f_pe, T_pe, dt_limit] = ...
        checkPlasmaFrequencyTimeStep(ui_ne.Value, 0.7);
    
    if ~is_ok_plasma_dt
        msg = sprintf(['Time step too large to resolve electron plasma oscillations.\n' ...
            'dt = %.3e s\n' ...
            'omega_pe = %.3e rad/s\n' ...
            'f_pe = %.3e Hz\n' ...
            'T_pe = %.3e s\n' ...
            'Required: dt <= %.3e s (safety factor = 0.1)\n' ...
            'Reduce dt or lower ne.'], ...
            sim.dt, omega_pe, f_pe, T_pe, dt_limit);
    
        uialert(fig, msg, 'Plasma Frequency Time-Step Warning');
        txt_status.Text = sprintf('Status: dt too large for plasma frequency (dt/Tpe = %.3f).', sim.dt / T_pe);
        return;
    end
    % Check ratio Dl/Dt
    [is_ok_step, vmax_est, dl_min_m, ratio_step] = checkParticleStepLimit();

    if ~is_ok_step
        msg = sprintf(['Particle step condition violated.\n' ...
            'Require vmax * dt < Dl_min everywhere.\n' ...
            'Estimated vmax = %.3e m/s\n' ...
            'dt = %.3e s\n' ...
            'Dl_min = %.3e m\n' ...
            'vmax*dt/Dl_min = %.3f\n' ...
            'Reduce dt or increase mesh spacing.'], ...
            vmax_est, sim.dt, dl_min_m, ratio_step);
    
        uialert(fig, msg, 'Particle Time-Step Warning');
        txt_status.Text = sprintf('Status: particle step check failed (ratio = %.3f).', ratio_step);
        return;
    end
    if ~is_ok_debye
        msg = sprintf(['Mesh too coarse for Debye-length resolution.\\n' ...
                       'dx = %.4f mm, dy = %.4f mm\\n' ...
                       'lambda_D = %.4f mm\\n' ...
                       'Require dx < lambda_D and dy < lambda_D.'], ...
                       dx, dy, lambdaD_mm);
        uialert(fig, msg, 'Debye Resolution Warning');
        txt_status.Text = sprintf('Status: Mesh too coarse (lambda_D = %.4f mm).', lambdaD_mm);
        return;
    else
        txt_status.Text = sprintf('Status: Debye check passed (lambda_D = %.4f mm).', lambdaD_mm);
    end

    p_x = []; p_y = []; p_vx = []; p_vy = []; p_isCEX = false(0,1);
    iter_history = []; ebs_history = []; div_history = [];
    mean_exit_ke_history = []; mean_exit_velocity_history = [];
    divergence_snapshots = {}; energy_snapshots  = {};
    recorded_frames = {};
    iteration = 0;
    chk_recordGif.Value = 0;
    chk_recordGif.Text = 'Record Frames (0)';

    txt_status.Text = 'Status: Building multi-grid domain...';
    drawnow;

    nx = round(Lx/dx) + 1;
    ny = round(Ly/dy) + 1;
    [X, Y] = meshgrid(linspace(0, Lx, nx), linspace(0, Ly, ny));

    V = zeros(ny, nx);
    isBound = false(ny, nx);
    V_fixed = zeros(ny, nx);
    damage_map = zeros(ny, nx);

    primaryHitCountGrid2 = 0;
    primaryHitCountGrid3 = 0;
    
    gridXStart = zeros(1, numel(grid_defs));
    gridXEnd   = zeros(1, numel(grid_defs));
    
    x_cursor = 0.3;
    for k = 1:numel(grid_defs)
        x_start = x_cursor;
        x_end = x_start + grid_defs(k).thickness;
    
        gridXStart(k) = x_start;
        gridXEnd(k) = x_end;
    
        in_grid = X >= x_start & X <= x_end;
        R_grid = grid_defs(k).holeRadius + max(0, (X - x_start)) * tand(grid_defs(k).chamfer);
        mask_k = in_grid & Y >= R_grid;
    
        isBound(mask_k) = true;
        V_fixed(mask_k) = grid_defs(k).voltage;
    
        x_cursor = x_end + grid_defs(k).gapAfter;
    end

    if ~isempty(grid_defs)
        isBound(:, 1) = true;
        V_fixed(:, 1) = grid_defs(1).voltage + 50;
    end

    recalcLaplace();
    update3DSurface();
end

function recalcLaplace()
% Solves the electrostatic potential on the current mesh with fixed grid
% boundary conditions, computes electric fields, and refreshes the live plot
% using a light background, grey/green streamlines, and energy-colored ions.

    V(isBound) = V_fixed(isBound);

    for i = 1:500
        V(2:end-1, 2:end-1) = 0.25 * ( ...
            V(3:end,   2:end-1) + ...
            V(1:end-2, 2:end-1) + ...
            V(2:end-1, 3:end)   + ...
            V(2:end-1, 1:end-2));
        V(isBound) = V_fixed(isBound);
        V(1, :) = V(2, :);
        V(end, :) = V(end-1, :);
        V(:, end) = V(:, end-1);
    end

    [Ex, Ey] = gradient(-V, dx*1e-3, dy*1e-3);

    cla(ax_live);
    hold(ax_live, 'on');
    box(ax_live, 'on');
    axis(ax_live, 'equal');
    xlim(ax_live, [0, Lx]);
    ylim(ax_live, [0, Ly]);
    xlabel(ax_live, 'Axial Position X (mm)');
    ylabel(ax_live, 'Radial Position Y (mm)');
    title(ax_live, 'Live Axisymmetric Plasma Extraction & E-Field');

    ax_live.Color = [0.97 0.98 1.00];
    ax_live.XColor = [0.15 0.15 0.15];
    ax_live.YColor = [0.15 0.15 0.15];

    % Plot grid/wall geometry
    [gy, gx] = find(isBound);
    scatter(ax_live, (gx-1)*dx, (gy-1)*dy, 8, [0.20 0.20 0.20], ...
        'filled', 'MarkerFaceAlpha', 0.65);

    % Streamline seed points near inlet / extraction region
    nSeeds = 18;
    startX = 0.15 * ones(1, nSeeds);
    startY = linspace(0.05, min(Ly-0.05, max(0.2, grid_defs(1).holeRadius*0.95)), nSeeds);

    % Plot streamlines of electric field
    h_stream = streamline(ax_live, X, Y, Ex, Ey, startX, startY);

    % Choose ONE of these two colors:
    streamColor = [0.55 0.55 0.55];   % grey
    % streamColor = [0.10 0.55 0.10]; % green

    if ~isempty(h_stream)
        for k = 1:numel(h_stream)
            if isgraphics(h_stream(k))
                h_stream(k).Color = streamColor;
                h_stream(k).LineWidth = 1.1;
            end
        end
    end

    % Energy colormap reserved for ions only
    energy_max_eV = max([grid_defs.voltage]) + 200;
    energy_max_eV = max(energy_max_eV, 1);

    blueRedMap = [linspace(0,1,256)', zeros(256,1), linspace(1,0,256)'];
    colormap(ax_live, blueRedMap);
    clim(ax_live, [0 energy_max_eV]);

    h_beam = scatter(ax_live, NaN, NaN, 7, NaN, 'filled', ...
        'MarkerFaceAlpha', 0.90, 'MarkerEdgeColor', 'none');
    %h_cex = scatter(ax_live, NaN, NaN, 10, NaN, 'filled', ... % Colored with sidebar
    
    %    'MarkerFaceAlpha', 0.90, 'MarkerEdgeColor', 'none');
    h_cex = scatter(ax_live, NaN, NaN, 3, [0.0 0.7 0.1], 'filled', ...
    'MarkerFaceAlpha', 0.85, 'MarkerEdgeColor', 'none');

    cb_energy = colorbar(ax_live, 'eastoutside');
    cb_energy.Label.String = 'Ion kinetic energy [eV]';
    cb_energy.Color = [0.1 0.1 0.1];

    txt_status.Text = 'Status: Domain Ready.';
end

function rebuildGridUI()
% Rebuilds the left-side dynamic grid editor so each grid appears in its
% own non-overlapping parameter panel, stacked vertically inside a
% scrollable container.

    if ~isempty(grid_ui)
        for i = 1:numel(grid_ui)
            if isfield(grid_ui(i), 'panel') && isvalid(grid_ui(i).panel)
                delete(grid_ui(i).panel);
            end
        end
    end

    grid_ui = struct('panel', {}, 'name', {}, 'voltage', {}, ...
                     'thickness', {}, 'holeRadius', {}, ...
                     'chamfer', {}, 'gapAfter', {});

    panelH = 205;
    gapH   = 12;
    topPad = 10;
    sidePad = 8;
    panelW = 250;

    totalH = topPad + numel(grid_defs) * panelH + max(0, numel(grid_defs)-1) * gapH + topPad;
    totalH = max(totalH, 380);

    gridContainer.Position = [0, 0, 260, totalH];

    for k = 1:numel(grid_defs)
        y0 = totalH - topPad - k*panelH - (k-1)*gapH;

        grid_ui(k).panel = uipanel(gridContainer, ...
            'Title', sprintf('Grid %d', k), ...
            'Position', [sidePad, y0, panelW, panelH], ...
            'BackgroundColor', '#FFFFFF');

        rowY = [155 125 95 65 35 5];
        labelX = 10;
        fieldX = 110;
        labelW = 90;
        fieldW = 120;
        rowH = 22;

        uilabel(grid_ui(k).panel, 'Text', 'Name:', ...
            'Position', [labelX, rowY(1), labelW, rowH]);
        grid_ui(k).name = uieditfield(grid_ui(k).panel, 'text', ...
            'Position', [fieldX, rowY(1), fieldW, rowH], ...
            'Value', grid_defs(k).name);

        uilabel(grid_ui(k).panel, 'Text', 'Voltage (V):', ...
            'Position', [labelX, rowY(2), labelW, rowH]);
        grid_ui(k).voltage = uieditfield(grid_ui(k).panel, 'numeric', ...
            'Position', [fieldX, rowY(2), fieldW, rowH], ...
            'Value', grid_defs(k).voltage);

        uilabel(grid_ui(k).panel, 'Text', 'Thickness (mm):', ...
            'Position', [labelX, rowY(3), labelW, rowH]);
        grid_ui(k).thickness = uieditfield(grid_ui(k).panel, 'numeric', ...
            'Position', [fieldX, rowY(3), fieldW, rowH], ...
            'Value', grid_defs(k).thickness);

        uilabel(grid_ui(k).panel, 'Text', 'Hole R (mm):', ...
            'Position', [labelX, rowY(4), labelW, rowH]);
        grid_ui(k).holeRadius = uieditfield(grid_ui(k).panel, 'numeric', ...
            'Position', [fieldX, rowY(4), fieldW, rowH], ...
            'Value', grid_defs(k).holeRadius);

        uilabel(grid_ui(k).panel, 'Text', 'Chamfer (deg):', ...
            'Position', [labelX, rowY(5), labelW, rowH]);
        grid_ui(k).chamfer = uieditfield(grid_ui(k).panel, 'numeric', ...
            'Position', [fieldX, rowY(5), fieldW, rowH], ...
            'Value', grid_defs(k).chamfer);

        uilabel(grid_ui(k).panel, 'Text', 'Gap after (mm):', ...
            'Position', [labelX, rowY(6), labelW, rowH]);
        grid_ui(k).gapAfter = uieditfield(grid_ui(k).panel, 'numeric', ...
            'Position', [fieldX, rowY(6), fieldW, rowH], ...
            'Value', grid_defs(k).gapAfter);
    end

    drawnow;
    gridScroll.Scrollable = 'on';
end

function init3D(~, ~)
% Opens or focuses the 3D viewer and renders the current revolved grid
% surface together with live primary and CEX particle clouds.
    if isempty(isBound)
        uialert(fig, 'Build domain first to generate 3D model.', 'Warning');
        return;
    end

    if isempty(f3d) || ~isvalid(f3d)
        f3d = figure('Name', 'Live 3D Particle & Morphing Viewer', ...
            'Color', 'k', 'Position', [200, 200, 900, 700]);
        ax3d = axes(f3d);
        hold(ax3d, 'on');
        h_prim3d = scatter3(ax3d, NaN, NaN, NaN, 4, [0.3 0.6 1], 'filled', 'MarkerFaceAlpha', 0.6);
        h_cex3d = scatter3(ax3d, NaN, NaN, NaN, 8, [0.0 0.8 0.1], 'filled', 'MarkerFaceAlpha', 0.8);
        xlim(ax3d, [0, Lx]); ylim(ax3d, [-Ly, Ly]); zlim(ax3d, [-Ly, Ly]);
        axis(ax3d, 'manual');
        camlight(ax3d, 'headlight'); lighting(ax3d, 'gouraud'); material(ax3d, 'dull');
        set(ax3d, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'ZColor', 'w');
        title(ax3d, 'Live 3D Extraction & Surface Sputtering', 'Color', 'w');
        xlabel(ax3d, 'Axial Axis X (mm)'); ylabel(ax3d, 'Radial Y (mm)'); zlabel(ax3d, 'Radial Z (mm)');
        view(ax3d, [0, 0]); grid(ax3d, 'on');
        update3DSurface();
    else
        figure(f3d);
    end
end

function x_exit = getLastGridExit()
% Returns the downstream axial coordinate of the last grid exit plane,
% used for divergence extraction and plume diagnostics.
    x_cursor = 0.3;
    x_end = x_cursor;
    for kk = 1:numel(grid_defs)
        x_start = x_cursor;
        x_end = x_start + grid_defs(kk).thickness;
        x_cursor = x_end + grid_defs(kk).gapAfter;
    end
    x_exit = x_end;
end

function [is_ok, lambdaD_mm, target_mm] = checkDebyeResolution(Te_eV, ne_m3, safetyFactor)
% Computes the electron Debye length and checks whether the mesh spacing
% satisfies a user-defined fraction of the Debye length.

    if nargin < 3
        safetyFactor = 0.5;
    end

    eps0 = 8.854187817e-12;
    e    = 1.602176634e-19;

    if Te_eV <= 0 || ne_m3 <= 0
        error('Electron temperature and density must be positive.');
    end
    if safetyFactor <= 0 || safetyFactor > 1
        error('safetyFactor must be in the interval (0,1].');
    end

    Te_J = Te_eV * e;
    lambdaD_m  = sqrt(eps0 * Te_J / (ne_m3 * e^2));
    lambdaD_mm = lambdaD_m * 1e3;
    target_mm  = safetyFactor * lambdaD_mm;

    is_ok = (dx <= target_mm) && (dy <= target_mm);
end

function [is_ok, omega_pe, f_pe, T_pe, dt_limit] = checkPlasmaFrequencyTimeStep(ne_m3, safetyFactor)
    if nargin < 2
        safetyFactor = 0.1;   % require dt <= 10% of the plasma period
    end

    eps0 = 8.854187817e-12;
    e    = 1.602176634e-19;
    me   = 9.1093837015e-31;

    if ne_m3 <= 0
        error('Electron density must be positive.');
    end
    if safetyFactor <= 0 || safetyFactor > 1
        error('safetyFactor must be in the interval (0,1].');
    end

    omega_pe = sqrt(ne_m3 * e^2 / (eps0 * me));   % rad/s
    f_pe     = omega_pe / (2*pi);                 % Hz
    T_pe     = 1 / f_pe;                          % s

    dt_limit = safetyFactor * T_pe;
    is_ok = sim.dt <= dt_limit;
end

function [isOK, vmax_est, dl_min_m, ratio] = checkParticleStepLimit()
    dl_min_m = min(dx, dy) * 1e-3;   % mm -> m

    energy_max_eV = max([grid_defs.voltage])*0.5;
    energy_max_eV = max(energy_max_eV, ui_Ti.Value);

    vmax_est = sqrt(2 * sim.q * energy_max_eV / sim.m_XE);
    ratio = vmax_est * sim.dt / dl_min_m;

    isOK = ratio < 1.0;
end

function update3DSurface()
% Rebuilds the revolved 3D grid surface from the current 2D boundary and
% maps accumulated sputter damage as the surface color field.
    if isempty(f3d) || ~isvalid(f3d) || isempty(X)
        return;
    end

    if ~isempty(h_surf3d) && isvalid(h_surf3d)
        delete(h_surf3d);
    end

    x_range = X(1, :);
    R_profile = zeros(size(x_range));
    D_profile = zeros(size(x_range));
    for i = 1:length(x_range)
        solid_y = find(isBound(:, i));
        if ~isempty(solid_y)
            iy = solid_y(1);
            R_profile(i) = Y(iy, 1);
            D_profile(i) = damage_map(iy, i);
        else
            R_profile(i) = NaN;
            D_profile(i) = NaN;
        end
    end

    theta_surf = linspace(0, 2*pi, 60);
    [Theta_mat, X_mat] = meshgrid(theta_surf, x_range);
    R_mat = repmat(R_profile', 1, length(theta_surf));
    C_mat = repmat(D_profile', 1, length(theta_surf));
    Y_mat = R_mat .* cos(Theta_mat);
    Z_mat = R_mat .* sin(Theta_mat);

    h_surf3d = surf(ax3d, X_mat, Y_mat, Z_mat, C_mat, 'EdgeColor', 'none');
    colormap(ax3d, flipud(hot(256)));
    if ~isempty(h_prim3d) && isvalid(h_prim3d), uistack(h_prim3d, 'top'); end
    if ~isempty(h_cex3d) && isvalid(h_cex3d), uistack(h_cex3d, 'top'); end
end

function update3DSurfaceColor()
% Updates only the 3D surface color field using the latest sputter damage,
% avoiding a full geometry rebuild when only damage changes.
    if isempty(f3d) || ~isvalid(f3d) || isempty(h_surf3d) || ~isvalid(h_surf3d)
        return;
    end
    x_range = X(1, :);
    D_profile = zeros(size(x_range));
    for i = 1:length(x_range)
        solid_y = find(isBound(:, i));
        if ~isempty(solid_y)
            D_profile(i) = damage_map(solid_y(1), i);
        else
            D_profile(i) = NaN;
        end
    end
    C_mat = repmat(D_profile', 1, 60);
    set(h_surf3d, 'CData', C_mat);
end

function saveGif(~, ~)
% Saves the recorded GUI frames as an animated GIF and resets the frame
% buffer once the export completes successfully.
    if isempty(recorded_frames)
        uialert(fig, 'No frames recorded!', 'Error');
        return;
    end
    was_running = sim.isRunning;
    sim.isRunning = false;
    [filename, pathname] = uiputfile('*.gif', 'Save Animation');
    if ~isequal(filename, 0)
        full_path = fullfile(pathname, filename);
        for idx = 1:length(recorded_frames)
            im = frame2im(recorded_frames{idx});
            [imind, cm] = rgb2ind(im, 256);
            if idx == 1
                imwrite(imind, cm, full_path, 'gif', 'Loopcount', inf, 'DelayTime', 0.05);
            else
                imwrite(imind, cm, full_path, 'gif', 'WriteMode', 'append', 'DelayTime', 0.05);
            end
        end
        recorded_frames = {};
        chk_recordGif.Value = 0;
        chk_recordGif.Text = 'Record Frames (0)';
        uialert(fig, 'GIF Saved Successfully!', 'Success');
    end
    sim.isRunning = was_running;
end

function saveDivergenceData(~, ~)
% Exports divergence telemetry, EBS telemetry, angular snapshots, and the
% current simulation parameters into a MATLAB .mat file for later analysis.
    if isempty(iter_history) || isempty(div_history)
        uialert(fig, 'No divergence data available yet.', 'Warning');
        return;
    end
    was_running = sim.isRunning;
    sim.isRunning = false;
    [filename, pathname] = uiputfile('*.mat', 'Save Divergence Data', 'divergence_data.mat');
    if ~isequal(filename, 0)
        syncGridDefsFromUI();
        iter_history_out = iter_history;
        div_history_deg = div_history;
        ebs_history_V = ebs_history;
        divergence_snapshots_out = divergence_snapshots;
        grid_defs_out = grid_defs;
        sim_params = struct( ...
            'ion_temp_eV', ui_Ti.Value, ...
            'neutral_temp_K', ui_Tn.Value, ...
            'neutral_density_m3', ui_n0.Value, ...
            'accel_factor', ui_Accel.Value, ...
            'cell_fail_threshold', ui_Thresh.Value, ...
            'dt_s', sim.dt, ...
            'ion_mass_kg', sim.m_XE, ...
            'ion_charge_C', sim.q, ...
            'domain_Lx_mm', Lx, ...
            'domain_Ly_mm', Ly, ...
            'dx_mm', dx, ...
            'dy_mm', dy);
        save(fullfile(pathname, filename), ...
            'iter_history_out', 'div_history_deg', 'ebs_history_V', ...
            'divergence_snapshots_out', 'grid_defs_out', 'sim_params');
        uialert(fig, 'Divergence data saved successfully.', 'Success');
    end
    sim.isRunning = was_running;
end

    function saveVelocityData(~, ~)
    % Exports mean exit kinetic energy telemetry into a MATLAB .mat file.
    if isempty(iter_history) || isempty(mean_exit_ke_history)
        uialert(fig, 'No exit energy data available yet.', 'Warning');
        return;
    end

    was_running = sim.isRunning;
    sim.isRunning = false;

    [filename, pathname] = uiputfile('*.mat', 'Save Exit Energy Data', 'exit_energy_data.mat');

    if ~isequal(filename, 0)
        syncGridDefsFromUI();

        iter_history_out = iter_history;
        mean_exit_energy_eV = mean_exit_ke_history;
        exit_energy_snapshots_out = energy_snapshots ;   % optional, can be renamed later
        grid_defs_out = grid_defs;

        sim_params = struct( ...
            'ion_temp_eV', ui_Ti.Value, ...
            'electron_temp_eV', ui_Te.Value, ...
            'neutral_temp_K', ui_Tn.Value, ...
            'electron_density_m3', ui_ne.Value, ...
            'neutral_density_m3', ui_n0.Value, ...
            'accel_factor', ui_Accel.Value, ...
            'cell_fail_threshold', ui_Thresh.Value, ...
            'dt_s', sim.dt, ...
            'ion_mass_kg', sim.m_XE, ...
            'ion_charge_C', sim.q, ...
            'domain_Lx_mm', Lx, ...
            'domain_Ly_mm', Ly, ...
            'dx_mm', dx, ...
            'dy_mm', dy);

        save(fullfile(pathname, filename), ...
            'iter_history_out', ...
            'mean_exit_energy_eV', ...
            'exit_energy_snapshots_out', ...
            'grid_defs_out', ...
            'sim_params');

        uialert(fig, 'Exit energy data saved successfully.', 'Success');
    end

    sim.isRunning = was_running;
end
function saveDivergenceDataToMat(matFullPath, runIndex, paramValue, targetIterations)
    iter_history_out = iter_history;
    div_history_deg = div_history;
    ebs_history_V = ebs_history;
    divergence_snapshots_out = divergence_snapshots;
    grid_defs_out = grid_defs;

    sweep_run_info = struct( ...
        'run_index', runIndex, ...
        'sweep_parameter', sweepConfig.parameter, ...
        'sweep_value', paramValue, ...
        'sweep_min', sweepConfig.minVal, ...
        'sweep_max', sweepConfig.maxVal, ...
        'sweep_time_s', sweepConfig.time_s, ...
        'sweep_points', sweepConfig.points, ...
        'target_iterations', targetIterations, ...
        'completed_iterations', iteration, ...
        'primary_hit_count_grid2', primaryHitCountGrid2, ...
        'primary_hit_count_grid3', primaryHitCountGrid3);

    sim_params = struct( ...
        'ion_temp_eV', ui_Ti.Value, ...
        'electron_temp_eV', ui_Te.Value, ...
        'neutral_temp_K', ui_Tn.Value, ...
        'electron_density_m3', ui_ne.Value, ...
        'neutral_density_m3', ui_n0.Value, ...
        'accel_factor', ui_Accel.Value, ...
        'cell_fail_threshold', ui_Thresh.Value, ...
        'dt_s', sim.dt, ...
        'ion_mass_kg', sim.m_XE, ...
        'ion_charge_C', sim.q, ...
        'domain_Lx_mm', Lx, ...
        'domain_Ly_mm', Ly, ...
        'dx_mm', dx, ...
        'dy_mm', dy);

    save(matFullPath, ...
        'iter_history_out', 'div_history_deg', 'ebs_history_V', ...
        'divergence_snapshots_out', 'grid_defs_out', ...
        'sweep_run_info', 'sim_params');
end

function onSweep(~, ~)
    if ~isempty(sweepFig) && isvalid(sweepFig)
        figure(sweepFig);
        return;
    end

    sweepFig = uifigure( ...
        'Name', 'Sweep Setup', ...
        'Position', [200, 200, 430, 360], ...
        'Color', [0.98 0.98 0.99], ...
        'CloseRequestFcn', @onCloseSweepWindow);

    uilabel(sweepFig, ...
        'Text', 'Sweep parameter:', ...
        'Position', [25, 300, 120, 22], ...
        'FontWeight', 'bold');

    sweepUI.ddParam = uidropdown(sweepFig, ...
        'Position', [160, 300, 180, 22], ...
        'Items', {'Chamfer', 'Screen radius', 'Spacing'}, ...
        'Value', sweepConfig.parameter);

    uilabel(sweepFig, ...
        'Text', 'Min:', ...
        'Position', [25, 250, 120, 22], ...
        'FontWeight', 'bold');

    sweepUI.efMin = uieditfield(sweepFig, 'numeric', ...
        'Position', [160, 250, 180, 22], ...
        'Value', sweepConfig.minVal);

    uilabel(sweepFig, ...
        'Text', 'Max:', ...
        'Position', [25, 210, 120, 22], ...
        'FontWeight', 'bold');

    sweepUI.efMax = uieditfield(sweepFig, 'numeric', ...
        'Position', [160, 210, 180, 22], ...
        'Value', sweepConfig.maxVal);

    uilabel(sweepFig, ...
        'Text', 'Time (s):', ...
        'Position', [25, 170, 120, 22], ...
        'FontWeight', 'bold');

    sweepUI.efTime = uieditfield(sweepFig, 'numeric', ...
    'Position', [160, 170, 180, 22], ...
    'Value', sweepConfig.time_s, ...
    'LowerLimit', 0, ...
    'ValueDisplayFormat', '%.3g');

    uilabel(sweepFig, ...
        'Text', 'Points:', ...
        'Position', [25, 130, 120, 22], ...
        'FontWeight', 'bold');

    sweepUI.efPoints = uieditfield(sweepFig, 'numeric', ...
        'Position', [160, 130, 180, 22], ...
        'Value', sweepConfig.points, ...
        'LowerLimit', 1, ...
        'RoundFractionalValues', 'on');

    sweepUI.btnConfirm = uibutton(sweepFig, ...
        'Text', 'Run Sweep', ...
        'Position', [60, 55, 120, 32], ...
        'ButtonPushedFcn', @onConfirmSweepSettings);

    sweepUI.btnCancel = uibutton(sweepFig, ...
        'Text', 'Close', ...
        'Position', [220, 55, 120, 32], ...
        'ButtonPushedFcn', @(~,~) onCloseSweepWindow());
end

function onConfirmSweepSettings(~, ~)
    sweepConfig.parameter = sweepUI.ddParam.Value;
    sweepConfig.minVal = sweepUI.efMin.Value;
    sweepConfig.maxVal = sweepUI.efMax.Value;
    sweepConfig.time_s = sweepUI.efTime.Value;
    sweepConfig.points = sweepUI.efPoints.Value;

    if sweepConfig.points < 1 || round(sweepConfig.points) ~= sweepConfig.points
        uialert(sweepFig, 'Points must be a positive integer.', 'Invalid Input');
        return;
    end

    if sweepConfig.maxVal>0 && sweepConfig.maxVal < sweepConfig.minVal
        uialert(sweepFig, 'Max must be greater than or equal to Min.', 'Invalid Input');
        return;
    end

    runSweep();
    end

function runSweep()
    sim.isSweepRunning = true;
    sim.stopSweepRequested = false;
    
    btn_toggle.Text = 'STOP SWEEP';
    btn_toggle.BackgroundColor = [1 0.25 0.25];
    
    lbl_sweepStatus.Text = 'Sweep: preparing...';
    drawnow;
    [baseCsvName, outPath] = uiputfile('*.csv', 'Choose sweep output base file', 'sweep_run_01.csv');
    if isequal(baseCsvName, 0) || isequal(outPath, 0)
        return;
    end
    was_running = sim.isRunning;
    sim.isRunning = false;

    syncGridDefsFromUI();

    base_grid_defs = grid_defs;
    base_chk_erosion = chk_erosion.Value;
    base_record_gif = chk_recordGif.Value;

    chk_recordGif.Value = false;
    chk_recordGif.Text = 'Record Frames (0)';

    sweepValues = linspace(sweepConfig.minVal, sweepConfig.maxVal, sweepConfig.points);
    nRuns = numel(sweepValues);

    sweepResults = repmat(struct( ...
        'runIndex', [], ...
        'parameter', '', ...
        'parameterValue', [], ...
        'time_s', [], ...
        'targetIterations', [], ...
        'finalIteration', [], ...
        'finalDivergence_deg', [], ...
        'finalEBS_V', [], ...
        'div_history', [], ...
        'ebs_history', [], ...
        'iter_history', [], ...
        'grid_defs', []), nRuns, 1);

    targetIterations = max(1, ceil(sweepConfig.time_s / sim.dt));

    if targetIterations > 1e7
        choice = uiconfirm(fig, ...
            sprintf(['Requested simulated time requires %d iterations per run.\n' ...
                     'This may take a very long time.\n' ...
                     'Do you want to continue?'], targetIterations), ...
            'Large Sweep', ...
            'Options', {'Continue', 'Cancel'}, ...
            'DefaultOption', 2, ...
            'CancelOption', 2);

        if ~strcmp(choice, 'Continue')
            return;
        end
    end

    txt_status.Text = sprintf('Status: Sweep started (%d runs)...', nRuns);
    lbl_sweepStatus.Text = 'Sweep: starting first run...';
    drawnow;
    
    for iRun = 1:nRuns
        grid_defs = base_grid_defs;
        applySweepValue(sweepConfig.parameter, sweepValues(iRun));

        rebuildGridUI();
        buildDomain([], []);

        txt_status.Text = sprintf('Status: Sweep run %d/%d | %s = %.6g', ...
            iRun, nRuns, sweepConfig.parameter, sweepValues(iRun));
        drawnow;

        runSingleSimulationForIterations(targetIterations, iRun, nRuns);
        csvName = sprintf('sweep_run_%03d.csv', iRun);
        matName = sprintf('sweep_run_%03d_divergence.mat', iRun);
        
        csvFullPath = fullfile(outPath, csvName);
        matFullPath = fullfile(outPath, matName);
        
        saveSweepRunCSV(csvFullPath, iRun, sweepValues(iRun), targetIterations);
        saveDivergenceDataToMat(matFullPath, iRun, sweepValues(iRun), targetIterations);
        finalDiv = NaN;
        finalEBS = NaN;

        if ~isempty(div_history)
            finalDiv = div_history(end);
        end

        if ~isempty(ebs_history)
            finalEBS = ebs_history(end);
        end

        sweepResults(iRun).runIndex = iRun;
        sweepResults(iRun).parameter = sweepConfig.parameter;
        sweepResults(iRun).parameterValue = sweepValues(iRun);
        sweepResults(iRun).time_s = sweepConfig.time_s;
        sweepResults(iRun).targetIterations = targetIterations;
        sweepResults(iRun).finalIteration = iteration;
        sweepResults(iRun).finalDivergence_deg = finalDiv;
        sweepResults(iRun).finalEBS_V = finalEBS;
        sweepResults(iRun).div_history = div_history;
        sweepResults(iRun).ebs_history = ebs_history;
        sweepResults(iRun).iter_history = iter_history;
        sweepResults(iRun).grid_defs = grid_defs;
    end

    grid_defs = base_grid_defs;
    rebuildGridUI();
    buildDomain([], []);

    chk_erosion.Value = base_chk_erosion;
    chk_recordGif.Value = base_record_gif;
    sim.isRunning = was_running;

    if sim.stopSweepRequested
        uialert(fig, 'Sweep stopped by user.', 'Sweep Stopped');
        lbl_sweepStatus.Text = 'Sweep: stopped by user';
    else
        uialert(fig, sprintf('Sweep completed: %d runs finished.', nRuns), 'Sweep Done');
        lbl_sweepStatus.Text = sprintf('Sweep: completed (%d runs)', nRuns);
    end
    
    sim.isSweepRunning = false;
    sim.stopSweepRequested = false;
    
    btn_toggle.Text = '2. START BEAM EXTRACTION';
    btn_toggle.BackgroundColor = [0.8 1 0.8];
    drawnow;
end

function applySweepValue(paramName, paramValue)
    switch lower(strtrim(paramName))
        case 'chamfer'
            grid_defs(1).chamfer = paramValue;

        case 'screen radius'
            grid_defs(1).holeRadius = paramValue;

        case 'spacing'
            if numel(grid_defs) < 1
                error('No grids available.');
            end
            grid_defs(1).gapAfter = paramValue;

        otherwise
            error('Unknown sweep parameter: %s', paramName);
    end
end

function onCloseSweepWindow(~, ~)
    if ~isempty(sweepFig) && isvalid(sweepFig)
        delete(sweepFig);
    end
    sweepFig = [];
    sweepUI = struct();
end

function onSaveAsPng(~, ~)
    [filename, pathname] = uiputfile('*.png', 'Save first plot as PNG', 'live_extraction.png');

    if isequal(filename, 0) || isequal(pathname, 0)
        return; % user cancelled
    end

    fullpath = fullfile(pathname, filename);

    try
        exportgraphics(ax_live, fullpath, ...
            'Resolution', 300, ...
            'BackgroundColor', 'white');
        uialert(fig, 'PNG saved successfully.', 'Success');
    catch ME
        uialert(fig, sprintf('Failed to save PNG:\n%s', ME.message), 'Save Error');
    end
end

function saveSweepRunCSV(csvFullPath, runIndex, paramValue, targetIterations)
    syncGridDefsFromUI();

    row = table();

    row.run_index = runIndex;
    row.iterations_target = targetIterations;
    row.iterations_completed = iteration;

    row.sweep_parameter = string(sweepConfig.parameter);
    row.sweep_value = paramValue;
    row.sweep_min = sweepConfig.minVal;
    row.sweep_max = sweepConfig.maxVal;
    row.sweep_time_s = sweepConfig.time_s;
    row.sweep_points = sweepConfig.points;

    row.ion_temp_eV = ui_Ti.Value;
    row.electron_temp_eV = ui_Te.Value;
    row.neutral_temp_K = ui_Tn.Value;
    row.electron_density_m3 = ui_ne.Value;
    row.neutral_density_m3 = ui_n0.Value;
    row.accel_factor = ui_Accel.Value;
    row.cell_fail_thresh = ui_Thresh.Value;

    row.dt_s = sim.dt;
    row.domain_Lx_mm = Lx;
    row.domain_Ly_mm = Ly;
    row.dx_mm = dx;
    row.dy_mm = dy;

    row.primary_hit_count_grid2 = primaryHitCountGrid2;
    row.primary_hit_count_grid3 = primaryHitCountGrid3;

    nGrids = numel(grid_defs);
    row.num_grids = nGrids;

    for k = 1:nGrids
        row.(sprintf('grid%d_voltage_V', k)) = grid_defs(k).voltage;
        row.(sprintf('grid%d_thickness_mm', k)) = grid_defs(k).thickness;
        row.(sprintf('grid%d_holeRadius_mm', k)) = grid_defs(k).holeRadius;
        row.(sprintf('grid%d_chamfer_deg', k)) = grid_defs(k).chamfer;
        row.(sprintf('grid%d_gapAfter_mm', k)) = grid_defs(k).gapAfter;
    end

    writetable(row, csvFullPath);
end

    function recordTelemetrySnapshot()
    if isempty(V)
        return;
    end

    max_grid_x = getLastGridExit();
    post_grid_mask = (~p_isCEX) & (p_x > max_grid_x) & (p_vx > 0);

    angles = [];
    mean_exit_ke_eV = NaN;
    mean_exit_velocity_mps = NaN;

    if sum(post_grid_mask) > 5
        vx_exit = p_vx(post_grid_mask);
        vy_exit = p_vy(post_grid_mask);

        angles = abs(atan2(vy_exit, vx_exit)) * 180/pi;

        v_exit_mag = sqrt(vx_exit.^2 + vy_exit.^2);
        ke_exit_eV = 0.5 * sim.m_XE * v_exit_mag.^2 / sim.q;

        current_div = prctile(angles, 95);
        mean_exit_ke_eV = mean(ke_exit_eV);
        mean_exit_velocity_mps = mean(v_exit_mag);
    else
        current_div = NaN;
    end

    min_pot = min(V(1, :));

    iter_history = [iter_history, iteration];
    ebs_history = [ebs_history, min_pot];
    div_history = [div_history, current_div];
    mean_exit_ke_history = [mean_exit_ke_history, mean_exit_ke_eV];
    mean_exit_velocity_history = [mean_exit_velocity_history, mean_exit_velocity_mps];

    snapshot = struct();
    snapshot.iteration = iteration;
    snapshot.current_div_deg = current_div;
    snapshot.primary_angles_deg = angles;
    snapshot.num_post_grid = sum(post_grid_mask);
    divergence_snapshots{end+1} = snapshot;
end

function onClose(~, ~)
% Safely stops the simulation and closes any auxiliary 3D window before
% destroying the main GUI figure.
    sim.isRunning = false;
    if ~isempty(f3d) && isvalid(f3d)
        delete(f3d);
    end
    delete(fig);
end
end
