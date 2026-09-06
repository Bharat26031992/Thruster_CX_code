
%% Variables Declarations
numFig = 1;

% Evaluating Design point
T_design              = 0.00461; % [N]
dutycycle_design      = 224;    % [-]
tot_time_design       = 14.412;   % [days]
ecc_design            = 0.001830580658340012;  % [-]
mass_flow_rate_design = 1.197966346702621e-07; % [kg/s]
Isp_design            = 3916;   % [s]
mass_design           = 1.89;    % [kg]
Power_design          = 180;    % [W]
INC_design            = 98.0417; % [°] final inclination
m_prop_tot = 0.09106699041637611; 

%% Eccentricity, Inclination and duty cycle
ecc=[0.003430242230993542 0.002637943209212382 0.001336975459034475 0.002776786972716751...
    0.002516147137881568 0.001861026309200153 0.001757592192417175...
    0.002602126105204804 0.001442132196482917 ]; % [-]
%inc=[98.03 98.04 98.037 98.045 98.0417 98.045 98.053 98.054 98.067 98.075];
inc = [0.2 0.21 0.23 0.246 0.265 0.285 0.3 0.314 0.31];
dutycycle= [162 180 190 212 224 238 266 301 345 417];  
%tot_time = [14.67 17.1 18.85 22.715 26.83];    % [days]
figure(numFig);
clf; % Clear the figure to avoid overlapping with previous runs

% --- LEFT Y-AXIS (Eccentricity) ---
yyaxis left
plot(tot_time, ecc, '-ob', 'LineWidth', 2, 'MarkerSize', 6);
ylabel('Eccentricity [-]', 'FontSize', 14, 'FontWeight', 'bold');
ylim([0.0005 0.004]);   

% --- RIGHT Y-AXIS (Inclination) ---
yyaxis right
plot(tot_time, inc, '-sr', 'LineWidth', 2, 'MarkerSize', 6);
ylabel('Inclination [°]', 'FontSize', 14, 'FontWeight', 'bold');

% --- COMMON X-AXIS & ANNOTATIONS ---
xlabel('Mission time[days]', 'FontSize', 14, 'FontWeight', 'bold');
title('Eccentricity & Inclination vs Total Mission Time', 'FontSize', 16, 'FontWeight', 'bold');

% Make the axis numbers (ticks) bigger
set(gca, 'FontSize', 13); 

% Add a grid and a legend
grid on;
%legend('Eccentricity', 'Inclination', 'Location', 'best', 'FontSize', 12);

%% Constant ISP Graph - ISP 2450s
Thrust= [0.0065 0.006 0.0055 0.005 0.0045 0.004 0.0035 0.003 0.0025]; % [mN]
tot_time = [10.16 11 11.97 13.19 14.67 16.47 18.79 21.95 26.44];    % [days]
%mass_flow_rate = [4.974276152661033e-08 6.217845190826292e-08 8.207555651890704e-08...
%    8.704983267156808e-08 9.948552305322067e-08 9.177539501659604e-08 1.243569038165258e-07];
delta_v = [];

numFig = numFig+1;
figure(numFig);

% --- LEFT Y-AXIS (Thrust) ---
%yyaxis left
% Plot the main Thrust line (blue line with markers)
plot(tot_time, Thrust, '-b', 'LineWidth', 1.5); 
hold on; 

% Color the single design point differently (Red Circle, filled)
%plot(tot_time_design, T_design, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r'); 
ylabel('Thrust [mN]', 'FontSize', 14, 'FontWeight', 'bold');

% --- COMMON X-AXIS & ANNOTATIONS ---
xlabel('Mission Duration [Days]', 'FontSize', 14, 'FontWeight', 'bold')
title("Constant Isp - 2450s", 'FontSize', 16, 'FontWeight', 'bold')

% Draw a vertical line at Tot_time = 20 with a dashed black line ('--k')
xline(20, '--k', 'Constraint', 'LabelVerticalAlignment', 'top', 'FontSize', 12);

% Add a legend to make it clear which line is which
set(gca, 'FontSize', 13);
%legend('Thrust Curve', 'Design Point', 'Location', 'best', 'FontSize', 12);

hold off;


%% Constant Thrust 3.4  mN

%T   = 0.00461;
%Isp = [2500 3000 3500 3916 4000 4500 5000];       % [s]
%mass_flow_rate = [1.880375871228924e-07 1.56697989269077e-07 1.343125622306374e-07...
%    1.197966346702621e-07 1.175234919518077e-07 1.044653261793847e-07 9.401879356144619e-08];

T = 0.0035;
Isp = [1000 1500 2000 2450 3000 3500 4000];
%mass_flow_rate = [3.46707047840474e-07 2.311380318936493e-07 1.73353523920237e-07 1.415130807512139e-07...
%    1.155690159468247e-07 9.905915652584971e-08 8.66767619601185e-08];
mass_flow_rate = [3.569043139534291e-07 2.379362093022861e-07 1.784521569767146e-07 1.427617255813716e-07...
    1.18968104651143e-07 1.019726611295512e-07 8.922607848835728e-08 ];
efficiency = Isp.*(T*9.81 / (2*Power_design));
mass_flow_rate = T./Isp*9.81;

numFig = numFig+1;
figure(numFig);
Isp_design = 2450;
% --- LEFT Y-AXIS (Thrust) ---
yyaxis left
% Plot the main Thrust line (blue line with markers)
plot(Isp, mass_flow_rate, '-ob', 'LineWidth', 1.5); 
hold on; 

% Color the single design point differently (Red Circle, filled)
xline(Isp_design, '--k', 'Requirement','LabelVerticalAlignment', 'bottom', 'FontSize', 12); 

ylabel('Mass Flow Rate [kg/s]', 'FontSize', 14, 'FontWeight', 'bold');

% --- RIGHT Y-AXIS (Eccentricity) ---
yyaxis right
% Plot the eccentricity line (orange/red line)
plot(Isp, efficiency, '-sr', 'LineWidth', 1.5);
ylabel('Total Efficiency [-]', 'FontSize', 14, 'FontWeight', 'bold');

% --- COMMON X-AXIS & ANNOTATIONS ---
xlabel('Isp [s]', 'FontSize', 14, 'FontWeight', 'bold')
title('Constant Thrust 3.5 [mN]', 'FontSize', 16, 'FontWeight', 'bold')
set(gca, 'FontSize', 13)
% Add a legend to make it clear which line is which
%legend('Mass Flow rate Curve', 'Require Result', 'Efficiency', 'Location', 'best', 'FontSize', 12);

hold off;

%% Existing Thrusters

% RIT3.5  m = 0.44   P=120W   Isp = 3200s T = 0.8-2.2mN
% T5      m = 2.5    P=700W   Isp = 3500s T = 0.6-25mN
% RIT 10E m = 1.8    P=145W   Isp = 1900s T = 5mN
% RIT Artemis m=1.7 P = 600W Isp = 3000s T=15mN
% Design m=1.8 P=180W Isp = 4000 T = 3.5mN
Isp_design = 3916;
T   = 0.00461;

m   = [0.44 1.8  1.7];
P   = [120  145  600];
isp = [3200 1900 3000];


numFig = numFig+1;
figure(numFig);
clf

% --- LEFT Y-AXIS ---
yyaxis left
plot(m, P, 'o', 'LineWidth', 1.5);
hold on
%xline(mass_design, '--k', 'Final Design', 'LabelVerticalAlignment', 'bottom');
%plot(mass_design, Power_design, 'bo', ...
%    'MarkerSize', 8, 'MarkerFaceColor', 'b');
ylabel('Power [W]');
ylim([0 800]);   % Left axis scale

% --- RIGHT Y-AXIS ---
yyaxis right
plot(m, isp, 'o', 'LineWidth', 1.5);
hold on
%plot(mass_design, Isp_design, 'ro', ...
%    'MarkerSize', 8, 'MarkerFaceColor', 'r');
ylabel('Isp [s]');
ylim([1500 4500]);   % Right axis scale

% --- COMMON X-AXIS & ANNOTATIONS ---
xlabel('Mass [kg]');
title('Design comparison');
set(gca, 'FontSize', 13);
xlim([0 2.00]); 
%legend('Power', 'Design mass', 'Design Power/Mass', 'Isp', 'Design Isp', ...
%    'Location', 'best');

hold off