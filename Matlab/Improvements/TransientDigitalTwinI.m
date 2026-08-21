function TransientDigitalTwinI()
% --- 1. GLOBAL STATE & SIMULATION VARIABLES ---
sim.isRunning = false;
sim.dt = 2e-9;
sim.q = 1.602e-19;
sim.m_XE = 131.293 * 1.6605e-27;
sim.kB = 1.380649e-23;

% Vectorized Particle Arrays
p_x = []; p_y = []; p_vx = []; p_vy = []; p_isCEX = false(0,1);

% Mesh, Field, and Damage variables
X = []; Y = []; V = []; Ex = []; Ey = [];
isBound = []; V_fixed = []; damage_map = [];
Lx = 8; Ly = 4; dx = 0.05; dy = 0.05;

% Telemetry & 3D Objects
iter_history = [];
ebs_history = [];
div_history = [];
divergence_snapshots = {};
recorded_frames = {};
f3d = []; ax3d = []; h_surf3d = []; h_prim3d = []; h_cex3d = [];

% Grid stack definition for multi-grid support
grid_defs = struct( ...
    'name', {}, ...
    'voltage', {}, ...
    'thickness', {}, ...
    'holeRadius', {}, ...
    'chamfer', {}, ...
    'gapAfter', {});

ui_gridList = [];
btn_addGrid = [];
btn_removeGrid = [];

% --- 2. SETUP THE GUI (Ultra-Scaled for 125/150% Displays) ---
fig = uifigure( ...
    'Name', '2-Grid Digital Twin: Morphing, Telemetry & LIVE 3D', ...
    'Position', [20, 30, 1280, 780], ...
    'Color', '#F4F6F9', ...
    'CloseRequestFcn', @onClose);

grid_ui = struct( ...
    'panel', {}, ...
    'name', {}, ...
    'voltage', {}, ...
    'thickness', {}, ...
    'holeRadius', {}, ...
    'chamfer', {}, ...
    'gapAfter', {});

gridScroll = [];
gridContainer = [];

% Control Panel Container
pnl = uipanel(fig, 'Position', [10, 10, 300, 760], 'BackgroundColor', '#FFFFFF');

% --- 2A. ELECTRICAL & GEOMETRY ---
ypos = 730; step = 26;
uilabel(pnl, 'Text', '1. GRID DESIGN', 'Position', [10, ypos, 280, 22], ...
    'FontWeight', 'bold', 'FontColor', [0.1 0.3 0.6]); ypos = ypos - step;

uilabel(pnl, 'Text', 'Screen Volts (V):', 'Position', [10, ypos, 130, 22]);
ui_Vscreen = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 1000); ypos = ypos - step;

uilabel(pnl, 'Text', 'Accel Volts (V):', 'Position', [10, ypos, 130, 22]);
ui_Vaccel = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', -200); ypos = ypos - step;

uilabel(pnl, 'Text', 'Grid Gap (mm):', 'Position', [10, ypos, 130, 22], 'FontWeight', 'bold');
ui_Gap = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 1.0); ypos = ypos - step;

uilabel(pnl, 'Text', 'Screen Thick (mm):', 'Position', [10, ypos, 130, 22]);
ui_Tscreen = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 0.6); ypos = ypos - step;

uilabel(pnl, 'Text', 'Accel Thick (mm):', 'Position', [10, ypos, 130, 22]);
ui_Taccel = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 1.2); ypos = ypos - step;

uilabel(pnl, 'Text', 'Screen Hole R (mm):', 'Position', [10, ypos, 130, 22]);
ui_RadS = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 1.0); ypos = ypos - step;

uilabel(pnl, 'Text', 'Accel Hole R (mm):', 'Position', [10, ypos, 130, 22]);
ui_RadA = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 0.8); ypos = ypos - step;

uilabel(pnl, 'Text', 'Screen Chamfer (°):', 'Position', [10, ypos, 130, 22]);
ui_ChamferS = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 0); ypos = ypos - step;

uilabel(pnl, 'Text', 'Accel Chamfer (°):', 'Position', [10, ypos, 130, 22]);
ui_ChamferA = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 15); ypos = ypos - step - 5;

% --- 2A. GRID STACK GUI ---
ypos = 730; step = 26;

uilabel(pnl, 'Text', '1. GRID STACK', ...
    'Position', [10, ypos, 280, 22], ...
    'FontWeight', 'bold', 'FontColor', [0.1 0.3 0.6]);
ypos = ypos - step;

btn_addGrid = uibutton(pnl, ...
    'Text', 'ADD GRID', ...
    'Position', [10, ypos-5, 135, 30], ...
    'BackgroundColor', [0.80 0.92 1.00], ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @addGrid);

btn_removeGrid = uibutton(pnl, ...
    'Text', 'REMOVE LAST GRID', ...
    'Position', [155, ypos-5, 135, 30], ...
    'BackgroundColor', [1.00 0.88 0.88], ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @removeLastGrid);

ypos = ypos - 45;

gridScroll = uipanel(pnl, ...
    'Position', [10, 290, 280, 380], ...
    'BackgroundColor', [0.98 0.98 0.99], ...
    'Title', 'Grid Parameters');

gridContainer = uipanel(gridScroll, ...
    'Position', [0 0 260 360], ...
    'BackgroundColor', [0.98 0.98 0.99], ...
    'BorderType', 'none');

% --- 2B. PLASMA & MORPHING ---
uilabel(pnl, 'Text', '2. PLASMA & MORPHING', 'Position', [10, ypos, 280, 22], ...
    'FontWeight', 'bold', 'FontColor', [0.1 0.3 0.6]); ypos = ypos - step;

uilabel(pnl, 'Text', 'Ion Temp (eV):', 'Position', [10, ypos, 130, 22], 'FontColor', 'b');
ui_Ti = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 2.0); ypos = ypos - step;

uilabel(pnl, 'Text', 'Neutral Temp (K):', 'Position', [10, ypos, 130, 22], 'FontColor', '#D95319');
ui_Tn = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 300); ypos = ypos - step;

uilabel(pnl, 'Text', 'Neutral Dens n0:', 'Position', [10, ypos, 130, 22]);
ui_n0 = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 1e20); ypos = ypos - step;

uilabel(pnl, 'Text', 'Accel. Factor (X):', 'Position', [10, ypos, 130, 22], 'FontColor', 'r');
ui_Accel = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 5e13); ypos = ypos - step;

uilabel(pnl, 'Text', 'Cell Fail Thresh:', 'Position', [10, ypos, 130, 22], 'FontColor', 'r');
ui_Thresh = uieditfield(pnl, 'numeric', 'Position', [150, ypos, 130, 22], 'Value', 1.0); ypos = ypos - 15;

% Default two-grid configuration
grid_defs(1) = struct( ...
    'name', 'Screen', ...
    'voltage', 1000, ...
    'thickness', 0.6, ...
    'holeRadius', 1.0, ...
    'chamfer', 0, ...
    'gapAfter', 1.0);

grid_defs(2) = struct( ...
    'name', 'Accel', ...
    'voltage', -200, ...
    'thickness', 1.2, ...
    'holeRadius', 0.8, ...
    'chamfer', 15, ...
    'gapAfter', 0.0);

rebuildGridUI();

% --- 2C. EXECUTION BUTTONS ---
btn_recalc = uibutton(pnl, ...
    'Text', '1. BUILD DOMAIN', ...
    'Position', [10, ypos-25, 280, 35], ...
    'BackgroundColor', [1 0.9 0.6], ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @buildDomain);

btn_toggle = uibutton(pnl, ...
    'Text', '2. START BEAM EXTRACTION', ...
    'Position', [10, ypos-65, 280, 35], ...
    'BackgroundColor', [0.8 1 0.8], ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @toggleSim);

btn_3d = uibutton(pnl, ...
    'Text', 'OPEN LIVE 3D CAD VIEW', ...
    'Position', [10, ypos-105, 280, 35], ...
    'BackgroundColor', '#E0F7FA', ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @init3D);

chk_recordGif = uicheckbox(pnl, ...
    'Text', 'Record Frames (0)', ...
    'Position', [15, ypos-135, 200, 22], ...
    'FontWeight', 'bold', ...
    'FontColor', 'r');

btn_saveGif = uibutton(pnl, ...
    'Text', 'Save GIF Animation', ...
    'Position', [10, ypos-165, 280, 25], ...
    'BackgroundColor', [0.9 0.8 1], ...
    'ButtonPushedFcn', @saveGif);

btn_saveDiv = uibutton(pnl, ...
    'Text', 'Save Divergence .mat', ...
    'Position', [10, ypos-195, 280, 25], ...
    'BackgroundColor', [0.85 0.92 1.0], ...
    'ButtonPushedFcn', @saveDivergenceData);

txt_status = uilabel(pnl, ...
    'Text', 'Status: Ready.', ...
    'Position', [10, 5, 280, 30], ...
    'FontSize', 10, ...
    'FontWeight', 'bold', ...
    'FontColor', [0 0.5 0]);

% --- RIGHT PANEL: AXES LAYOUT ---
ax_live = uiaxes(fig, 'Position', [320, 380, 940, 390]);
title(ax_live, 'Live Axisymmetric Plasma Extraction & E-Field');
xlabel(ax_live, 'Axial Position X (mm)');
ylabel(ax_live, 'Radial Position Y (mm)');
hold(ax_live, 'on'); box(ax_live, 'on'); axis(ax_live, 'equal');
xlim(ax_live, [0, Lx]); ylim(ax_live, [0, Ly]);

h_contour = []; h_bound = [];
h_beam = scatter(ax_live, [], [], 2, 'b', 'filled', 'MarkerFaceAlpha', 0.6);
h_cex  = scatter(ax_live, [], [], 5, 'r', 'filled');

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

% --- 3. MAIN SIMULATION LOOP ---
iteration = 0;
while ishandle(fig)
    if sim.isRunning && ~isempty(Ex)
        iteration = iteration + 1;

        % 1. Inject Primaries
        num_inject = 30;
        new_y = linspace(0.05, ui_RadS.Value - 0.1, num_inject)' + (rand(num_inject,1)-0.5)*0.05;
        new_x = repmat(0.1, num_inject, 1);

        v_bohm   = sqrt(2 * sim.q * 50 / sim.m_XE);
        v_spread = sqrt(sim.q * ui_Ti.Value / sim.m_XE);

        p_x = [p_x; new_x];
        p_y = [p_y; new_y];
        p_vx = [p_vx; repmat(v_bohm, num_inject, 1) + randn(num_inject,1)*v_spread];
        p_vy = [p_vy; randn(num_inject,1)*v_spread];
        p_isCEX = [p_isCEX; false(num_inject, 1)];

        % 2. Push Particles
        Ex_p = interp2(X, Y, Ex, p_x, p_y, 'linear', 0);
        Ey_p = interp2(X, Y, Ey, p_x, p_y, 'linear', 0);

        p_vx = p_vx + (sim.q / sim.m_XE) .* Ex_p .* sim.dt;
        p_vy = p_vy + (sim.q / sim.m_XE) .* Ey_p .* sim.dt;
        p_x = p_x + p_vx .* sim.dt .* 1000;
        p_y = p_y + p_vy .* sim.dt .* 1000;

        % 3. Extract Telemetry
        max_grid_x = getLastGridExit();

        % Use only forward-moving primary ions beyond the downstream grid exit.
        post_grid_mask = (~p_isCEX) & (p_x > max_grid_x) & (p_vx > 0);

        angles = [];
        if sum(post_grid_mask) > 5
            angles = abs(atan2(p_vy(post_grid_mask), p_vx(post_grid_mask))) * 180/pi;
            current_div = prctile(angles, 95);
        else
            current_div = NaN;
        end

        min_pot = min(V(1, :));

        % 4. Hit Detection
        hit_grid = interp2(X, Y, double(isBound), p_x, p_y, 'nearest', 1) == 1;
        out_of_bounds = p_x < 0 | p_x > Lx | p_y < 0 | p_y > Ly | isnan(p_x);

        % 5. ENERGY-DEPENDENT SPUTTERING & MORPHING
        is_erosion_hit = hit_grid & p_isCEX;
        if any(is_erosion_hit)
            hx = p_x(is_erosion_hit); hy = p_y(is_erosion_hit);
            hvx = p_vx(is_erosion_hit); hvy = p_vy(is_erosion_hit);

            ix = min(size(X,2), max(1, round(hx / dx) + 1));
            iy = min(size(Y,1), max(1, round(hy / dy) + 1));

            v_mag_sq = hvx.^2 + hvy.^2;
            E_eV = (0.5 * sim.m_XE * v_mag_sq) / sim.q;

            Y_yield = zeros(size(E_eV));
            valid_E = E_eV > 30;
            Y_yield(valid_E) = 1.05e-4 .* (E_eV(valid_E) - 30).^1.5;

            damage_added = accumarray([iy, ix], Y_yield .* ui_Accel.Value, size(damage_map));
            damage_map = damage_map + damage_added;

            broken_cells = (damage_map > ui_Thresh.Value) & isBound;
            if any(broken_cells, 'all')
                isBound(broken_cells) = false;
                damage_map(broken_cells) = 0;

                txt_status.Text = 'Cell Failed! Remeshing Laplace...'; drawnow;
                recalcLaplace();
                update3DSurface();
                txt_status.Text = sprintf('Active Particles: %d | Iteration: %d', length(p_x), iteration);
            end
        end

        % Purge dead
        dead_mask = hit_grid | out_of_bounds;
        p_x(dead_mask) = [];
        p_y(dead_mask) = [];
        p_vx(dead_mask) = [];
        p_vy(dead_mask) = [];
        p_isCEX(dead_mask) = [];

        % 6. Charge Exchange (MCC)
        primary_mask = ~p_isCEX & (p_x > 1.0);
        if any(primary_mask)
            v_mag = sqrt(p_vx(primary_mask).^2 + p_vy(primary_mask).^2);
            g = max(v_mag, 1);
            sigma = ((-0.8821 .* log(g) + 15.1262).^2) .* 1e-20;
            prob = 1 - exp(-ui_n0.Value .* sigma .* g .* sim.dt);

            collided = rand(sum(primary_mask), 1) < (prob .* 1);
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

        % 7. GUI, Telemetry & LIVE 3D Updates
        if mod(iteration, 5) == 0
            set(h_beam, 'XData', p_x(~p_isCEX), 'YData', p_y(~p_isCEX));
            set(h_cex,  'XData', p_x(p_isCEX),  'YData', p_y(p_isCEX));

            iter_history = [iter_history, iteration];
            ebs_history  = [ebs_history, min_pot];
            div_history  = [div_history, current_div];

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
            contourf(ax_damage, X, Y, damage_map, 15, 'LineStyle', 'none');
            [gy, gx] = find(isBound);
            scatter(ax_damage, (gx-1)*dx, (gy-1)*dy, 2, [0.3 0.3 0.3], ...
                'filled', 'MarkerFaceAlpha', 0.5);
            xlim(ax_damage, [0.5, Lx]); ylim(ax_damage, [0, Ly]);

            if ~isempty(f3d) && isvalid(f3d)
                prim_mask = ~p_isCEX;
                if any(prim_mask)
                    th_p = rand(sum(prim_mask), 1) * 2 * pi;
                    set(h_prim3d, ...
                        'XData', p_x(prim_mask), ...
                        'YData', p_y(prim_mask).*cos(th_p), ...
                        'ZData', p_y(prim_mask).*sin(th_p));
                else
                    set(h_prim3d, 'XData', NaN, 'YData', NaN, 'ZData', NaN);
                end

                cex_mask = p_isCEX;
                if any(cex_mask)
                    th_c = rand(sum(cex_mask), 1) * 2 * pi;
                    set(h_cex3d, ...
                        'XData', p_x(cex_mask), ...
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

            drawnow;
        end
    else
        pause(0.1);
    end
end

% --- CALLBACK FUNCTIONS ---
function toggleSim(~, ~)
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
    syncGridDefsFromUI();

    newIdx = numel(grid_defs) + 1;
    grid_defs(newIdx) = struct( ...
        'name', sprintf('Grid%d', newIdx), ...
        'voltage', -100, ...
        'thickness', 1.0, ...
        'holeRadius', 0.7, ...
        'chamfer', 0.0, ...
        'gapAfter', 0.5);

    rebuildGridUI();
end

function removeLastGrid(~, ~)
    syncGridDefsFromUI();

    if numel(grid_defs) <= 1
        uialert(fig, 'At least one grid must remain.', 'Warning');
        return;
    end

    grid_defs(end) = [];
    rebuildGridUI();
end

function refreshGridList()
    if isempty(grid_defs)
        ui_gridList.Value = {'No grids defined yet.'};
        return;
    end

    lines = cell(1, numel(grid_defs));
    for k = 1:numel(grid_defs)
        lines{k} = sprintf('%d) %s | V=%.1f V | t=%.2f mm | r=%.2f mm | ch=%.1f deg | gap=%.2f mm', ...
            k, grid_defs(k).name, grid_defs(k).voltage, grid_defs(k).thickness, ...
            grid_defs(k).holeRadius, grid_defs(k).chamfer, grid_defs(k).gapAfter);
    end
    ui_gridList.Value = lines;
end
function syncGridDefsFromUI()
    for k = 1:numel(grid_ui)
        grid_defs(k).name       = grid_ui(k).name.Value;
        grid_defs(k).voltage    = grid_ui(k).voltage.Value;
        grid_defs(k).thickness  = grid_ui(k).thickness.Value;
        grid_defs(k).holeRadius = grid_ui(k).holeRadius.Value;
        grid_defs(k).chamfer    = grid_ui(k).chamfer.Value;
        grid_defs(k).gapAfter   = grid_ui(k).gapAfter.Value;
    end
end
function buildDomain(~, ~)
    sim.isRunning = false;
    btn_toggle.Text = '2. START BEAM EXTRACTION';
    btn_toggle.BackgroundColor = [0.8 1 0.8];

    p_x = []; p_y = []; p_vx = []; p_vy = []; p_isCEX = false(0,1);
    iter_history = []; ebs_history = []; div_history = [];
    divergence_snapshots = {};
    recorded_frames = {};

    txt_status.Text = 'Building multi-grid domain...';
    drawnow;

    % Keep first two grids synchronized with legacy fields if present
    if numel(grid_defs) >= 1
        grid_defs(1).name       = 'Screen';
        grid_defs(1).voltage    = ui_Vscreen.Value;
        grid_defs(1).thickness  = ui_Tscreen.Value;
        grid_defs(1).holeRadius = ui_RadS.Value;
        grid_defs(1).chamfer    = ui_ChamferS.Value;
        if numel(grid_defs) >= 2
            grid_defs(1).gapAfter = ui_Gap.Value;
        end
    end

    if numel(grid_defs) >= 2
        grid_defs(2).name       = 'Accel';
        grid_defs(2).voltage    = ui_Vaccel.Value;
        grid_defs(2).thickness  = ui_Taccel.Value;
        grid_defs(2).holeRadius = ui_RadA.Value;
        grid_defs(2).chamfer    = ui_ChamferA.Value;
        grid_defs(2).gapAfter   = 0;
    end

    refreshGridList();

    nx = round(Lx/dx) + 1;
    ny = round(Ly/dy) + 1;
    [X, Y] = meshgrid(linspace(0, Lx, nx), linspace(0, Ly, ny));

    V = zeros(ny, nx);
    isBound = false(ny, nx);
    V_fixed = zeros(ny, nx);
    damage_map = zeros(ny, nx);

    x_cursor = 1.0;

    for k = 1:numel(grid_defs)
        x_start = x_cursor;
        x_end   = x_start + grid_defs(k).thickness;

        in_grid = X >= x_start & X <= x_end;
        R_grid = grid_defs(k).holeRadius + max(0, (X - x_start)) * tand(grid_defs(k).chamfer);

        mask_k = in_grid & Y >= R_grid;
        isBound(mask_k) = true;
        V_fixed(mask_k) = grid_defs(k).voltage;

        x_cursor = x_end + grid_defs(k).gapAfter;
    end

    % Upstream boundary condition
    if ~isempty(grid_defs)
        isBound(:, 1) = true;
        V_fixed(:, 1) = grid_defs(1).voltage + 50;
    end

    recalcLaplace();
    update3DSurface();
end
function recalcLaplace()
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
    [~, h_contour] = contourf(ax_live, X, Y, V, 20, 'LineStyle', 'none'); %#ok<NASGU>
    colormap(ax_live, turbo);

    [gy, gx] = find(isBound);
    h_bound = scatter(ax_live, (gx-1)*dx, (gy-1)*dy, 12, 'k', 'filled', ...
        'MarkerFaceAlpha', 0.8); %#ok<NASGU>
    h_beam = scatter(ax_live, [], [], 2, 'b', 'filled', 'MarkerFaceAlpha', 0.6);
    h_cex  = scatter(ax_live, [], [], 5, 'r', 'filled');

    txt_status.Text = 'Domain Ready.';
end
    function rebuildGridUI()
    % Delete old grid UI panels
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

    panelH = 175;      % increased height to avoid internal overlap
    gapH   = 12;       % spacing between panels
    topPad = 10;
    sidePad = 8;
    panelW = 250;

    totalH = topPad + numel(grid_defs) * (panelH + gapH);
    totalH = max(totalH, 360);

    gridContainer.Position = [0, 0, 260, totalH];

    for k = 1:numel(grid_defs)
        y0 = totalH - topPad - k*panelH - (k-1)*gapH;

        grid_ui(k).panel = uipanel(gridContainer, ...
            'Title', sprintf('Grid %d', k), ...
            'Position', [sidePad, y0, panelW, panelH], ...
            'BackgroundColor', '#FFFFFF');

        % Row positions inside each grid panel
        row1 = 125;
        row2 = 95;
        row3 = 65;
        row4 = 35;
        row5 = 5;

        labelX = 10;
        fieldX = 110;
        labelW = 90;
        fieldW = 120;
        rowH = 22;

        uilabel(grid_ui(k).panel, 'Text', 'Name:', ...
            'Position', [labelX, row1, labelW, rowH]);
        grid_ui(k).name = uieditfield(grid_ui(k).panel, 'text', ...
            'Position', [fieldX, row1, fieldW, rowH], ...
            'Value', grid_defs(k).name);

        uilabel(grid_ui(k).panel, 'Text', 'Gap after (mm):', ...
            'Position', [labelX, row2, labelW, rowH]);
        grid_ui(k).gapAfter = uieditfield(grid_ui(k).panel, 'numeric', ...
            'Position', [fieldX, row2, fieldW, rowH], ...
            'Value', grid_defs(k).gapAfter);

        uilabel(grid_ui(k).panel, 'Text', 'Voltage (V):', ...
            'Position', [labelX, row3, labelW, rowH]);
        grid_ui(k).voltage = uieditfield(grid_ui(k).panel, 'numeric', ...
            'Position', [fieldX, row3, fieldW, rowH], ...
            'Value', grid_defs(k).voltage);

        uilabel(grid_ui(k).panel, 'Text', 'Thickness (mm):', ...
            'Position', [labelX, row4, labelW, rowH]);
        grid_ui(k).thickness = uieditfield(grid_ui(k).panel, 'numeric', ...
            'Position', [fieldX, row4, fieldW, rowH], ...
            'Value', grid_defs(k).thickness);

        uilabel(grid_ui(k).panel, 'Text', 'Hole R (mm):', ...
            'Position', [labelX, row5, labelW, rowH]);
        grid_ui(k).holeRadius = uieditfield(grid_ui(k).panel, 'numeric', ...
            'Position', [fieldX, row5, fieldW, rowH], ...
            'Value', grid_defs(k).holeRadius);
    end
    end

function init3D(~, ~)
    if isempty(isBound)
        uialert(fig, 'Build domain first to generate 3D model.', 'Warning');
        return;
    end

    if isempty(f3d) || ~isvalid(f3d)
        f3d = figure('Name', 'Live 3D Particle & Morphing Viewer', ...
            'Color', 'k', 'Position', [200, 200, 900, 700]);
        ax3d = axes(f3d);
        hold(ax3d, 'on');

        h_prim3d = scatter3(ax3d, NaN, NaN, NaN, 4, [0.3 0.6 1], ...
            'filled', 'MarkerFaceAlpha', 0.6);
        h_cex3d  = scatter3(ax3d, NaN, NaN, NaN, 8, [1 0.2 0.2], ...
            'filled', 'MarkerFaceAlpha', 0.8);

        xlim(ax3d, [0, Lx]);
        ylim(ax3d, [-Ly, Ly]);
        zlim(ax3d, [-Ly, Ly]);
        axis(ax3d, 'manual');

        camlight(ax3d, 'headlight');
        lighting(ax3d, 'gouraud');
        material(ax3d, 'dull');

        set(ax3d, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'ZColor', 'w');
        title(ax3d, 'Live 3D Extraction & Surface Sputtering', 'Color', 'w');
        xlabel(ax3d, 'Axial Axis X (mm)');
        ylabel(ax3d, 'Radial Y (mm)');
        zlabel(ax3d, 'Radial Z (mm)');

        view(ax3d, [0, 0]);
        grid(ax3d, 'on');

        update3DSurface();
    else
        figure(f3d);
    end
end


function x_exit = getLastGridExit()
    x_cursor = 1.0;
    for kk = 1:numel(grid_defs)
        x_start = x_cursor;
        x_end = x_start + grid_defs(kk).thickness;
        x_cursor = x_end + grid_defs(kk).gapAfter;
    end
    x_exit = x_end;
end

function update3DSurface()
    if isempty(f3d) || ~isvalid(f3d)
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
    uistack(h_prim3d, 'top');
    uistack(h_cex3d, 'top');
end

function update3DSurfaceColor()
    if isempty(f3d) || ~isvalid(f3d) || isempty(h_surf3d)
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
    if isempty(iter_history) || isempty(div_history)
        uialert(fig, 'No divergence data available yet.', 'Warning');
        return;
    end

    was_running = sim.isRunning;
    sim.isRunning = false;

    [filename, pathname] = uiputfile('*.mat', 'Save Divergence Data', 'divergence_data.mat');

    if ~isequal(filename, 0)
        iter_history_out = iter_history;
        div_history_deg = div_history;
        ebs_history_V = ebs_history;
        divergence_snapshots_out = divergence_snapshots;

        sim_params = struct( ...
            'Vscreen_V', ui_Vscreen.Value, ...
            'Vaccel_V', ui_Vaccel.Value, ...
            'grid_gap_mm', ui_Gap.Value, ...
            'screen_thickness_mm', ui_Tscreen.Value, ...
            'accel_thickness_mm', ui_Taccel.Value, ...
            'screen_hole_radius_mm', ui_RadS.Value, ...
            'accel_hole_radius_mm', ui_RadA.Value, ...
            'screen_chamfer_deg', ui_ChamferS.Value, ...
            'accel_chamfer_deg', ui_ChamferA.Value, ...
            'ion_temp_eV', ui_Ti.Value, ...
            'neutral_temp_K', ui_Tn.Value, ...
            'neutral_density_m3', ui_n0.Value, ...
            'accel_factor', ui_Accel.Value, ...
            'cell_fail_threshold', ui_Thresh.Value, ...
            'dt_s', sim.dt, ...
            'ion_mass_kg', sim.m_XE, ...
            'ion_charge_C', sim.q);

        save(fullfile(pathname, filename), ...
            'iter_history_out', ...
            'div_history_deg', ...
            'ebs_history_V', ...
            'divergence_snapshots_out', ...
            'sim_params');

        uialert(fig, 'Divergence data saved successfully.', 'Success');
    end

    sim.isRunning = was_running;
end

function onClose(~, ~)
    sim.isRunning = false;
    if ~isempty(f3d) && isvalid(f3d)
        delete(f3d);
    end
    delete(fig);
end
end