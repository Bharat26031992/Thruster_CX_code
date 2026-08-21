function [p_u, p_v, p_cex, coll_info] = apply_mcc_cex_with_grid_transmission( ...
    p_x, p_y, p_u, p_v, p_cex, sim, n0, rT,T0)
% APPLY_MCC_CEX_WITH_GRID_TRANSMISSION
%
% Purpose:
%   Monte Carlo charge-exchange update using a downstream neutral-density
%   estimate based on grid transmission.
%
% Physical idea:
%   1) Estimate an upstream / chamber-side neutral density field.
%   2) Reduce that density by the grid transmission factor:
%          T_g = (grid open-area fraction) * (Clausing factor)
%   3) Use the resulting downstream neutral density in the MCC collision step.
%
% Why:
%   This is better than assuming the full upstream neutral density is present
%   downstream of the grids. In gridded ion thrusters, the downstream neutral
%   population is reduced by the finite open area of the grids and by the
%   reduced conductance of finite-length apertures, commonly represented by
%   the Clausing factor.
%
% References:
%   - Goebel & Katz: neutral ingestion / grid conductance concepts, Clausing
%     factor treatment for finite aperture transmission.
%   - Soulas et al., "Modeling Neutral Densities Downstream of a Gridded Ion
%     Thruster": downstream neutral density should be modeled from transmitted
%     neutral flow, not assumed identical to chamber density.
%
% Inputs:
%   p_x, p_y   : particle positions
%   p_u, p_v   : particle velocities
%   p_cex      : logical flag for particles that have suffered CEX
%   sim        : simulation structure
%   n0, rT     : existing parameters from your model
%
% Required fields in sim:
%   sim.dt
%   sim.neut_vth
%   sim.grid_open_area_fraction   % e.g. 0.35
%   sim.clausing_factor           % e.g. 0.5 to 0.8
%
% Outputs:
%   p_u, p_v, p_cex : updated particles
%   coll_info       : diagnostics
    kB = 1.380649e-23;
    coll_info = struct();
    coll_info.n_coll = 0;
    coll_info.mean_sigma = 0;
    coll_info.mean_n_up = 0;
    coll_info.mean_n_down = 0;
    coll_info.mean_lambda = Inf;
    coll_info.max_Peq = 0;
    coll_info.Tg = sim.grid_open_area_fraction * sim.clausing_factor;

    if isempty(p_x)
        return;
    end

    % ------------------------------------------------------------
    % 1) Upstream/chamber-side neutral density surrogate
    % ------------------------------------------------------------
    % This is your existing approximate neutral-density shape function.
    % It is treated here as the "source-side" density before transmission
    % through the grid stack.
    a_val = 1 / (1 - 1/sqrt(2));

    R_dist = sqrt(p_y.^2 + (p_x + rT).^2);
    R_dist = max(R_dist, 1e-12);

    theta_ang = atan2(abs(p_y), (p_x + rT));

    n_up = n0 .* a_val .* (1 - 1 ./ sqrt(1 + (rT ./ R_dist).^2)) .* cos(theta_ang);
    n_up = max(n_up, 0);

    % ------------------------------------------------------------
    % 2) Grid transmission model
    % ------------------------------------------------------------
    % First-order downstream neutral density estimate:
    %
    %   T_g = alpha_open * q_c
    %   n_down = n_up * T_g
    %
    % where:
    %   alpha_open = open-area fraction of the grid set
    %   q_c        = Clausing factor (finite aperture conductance correction)
    %
    % This is a first-order closure. It assumes the downstream density is
    % proportional to transmitted neutral flux through the grid system.
    Tg = sim.grid_open_area_fraction .* sim.clausing_factor;
    Tg = max(min(Tg, 1), 0);

    n_down = n_up .* Tg;

    % Optional flux interpretation:
    % Gamma_down = (n_up * vth / 4) * Tg
    % If one uses the same characteristic thermal speed upstream/downstream,
    % this implies n_down ~ n_up * Tg as a first-order estimate.

    % ------------------------------------------------------------
    % 3) Relative speed and empirical CEX cross section
    % ------------------------------------------------------------
    g = sqrt(p_u.^2 + p_v.^2);

    % Guard against log(0) and unsafe extrapolation of the empirical fit.
    g_safe = max(g, 1.0);

    % Empirical xenon CEX cross section fit used in your existing model:
    % sigma = (a_cs^2) * 1e-20, with a_cs = -0.8821*log(g) + 15.1262
    %
    % This fit is an implementation choice and should be treated as empirical.
    a_cs = -0.8821 .* log(g_safe) + 15.1262;
    sigma = (a_cs .^ 2) .* 1e-20;

    % Clamp the cross section to a reasonable range for robustness.
    sigma = max(sigma, 0);
    sigma = min(sigma, 5e-19);

    % ------------------------------------------------------------
    % 4) Mean free path using downstream neutral density
    % ------------------------------------------------------------
    % Standard collision relation:
    %   lambda = 1 / (n * sigma)
    %
    % Here the local neutral density n is taken as the downstream density
    % after transmission through the grid set.
    lambda = Inf(size(g));
    valid_mask = (n_down > 0) & (sigma > 0);
    lambda(valid_mask) = 1 ./ (n_down(valid_mask) .* sigma(valid_mask));

    % Particle path length during one timestep.
    s_step = g .* sim.dt;

    % Exponential free-path sampling:
    %   s_coll = -lambda * ln(xi)
    xi = rand(size(g));
    s_coll = -log(max(xi, 1e-12)) .* lambda;

    collide_mask = s_coll <= s_step;

    % Diagnostic equivalent one-step collision probability:
    %   P_eq = 1 - exp(-n * sigma * v * dt)
    Peq = 1 - exp(-n_down .* sigma .* g .* sim.dt); % Goebel (4.3-5) 

    % ------------------------------------------------------------
    % 5) Post-collision velocity reset
    % ------------------------------------------------------------
    % This keeps your current simplified collision handling:
    % collided particles are assigned a thermalized velocity.
    %
    % Note:
    % A more complete physical model would distinguish fast neutrals and
    % slow ions created by charge exchange, instead of simply rethermalizing
    % the same tracked charged particle.
    n_coll = sum(collide_mask);
    if n_coll > 0
        fmaxw_u = 2 .* (sum(rand(n_coll, 3), 2) - 1.5);
        fmaxw_v = 2 .* (sum(rand(n_coll, 3), 2) - 1.5);

        %p_u(collide_mask) = sim.neut_vth .* fmaxw_u;
        %p_v(collide_mask) = sim.neut_vth .* fmaxw_v;

        % That makes the neutrals isotropic around zero mean. Treating them 
        % as a thermal background

        sigma_n = sqrt(kB *T0 / sim.m_XE);
        p_u(collide_mask)   = sigma_n .* randn(n_coll,1);
        p_v(collide_mask)   = sigma_n .* randn(n_coll,1);
        p_cex(collide_mask) = true;
    end

    % ------------------------------------------------------------
    % 6) Diagnostics
    % ------------------------------------------------------------
    coll_info.n_coll = n_coll;
    coll_info.mean_sigma = mean(sigma);
    coll_info.mean_n_up = mean(n_up);
    coll_info.mean_n_down = mean(n_down);
    if any(isfinite(lambda))
        coll_info.mean_lambda = mean(lambda(isfinite(lambda)));
    end
    coll_info.max_Peq = max(Peq);
end