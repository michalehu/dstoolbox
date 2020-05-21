close all
clear all
clc
set(0,'DefaultFigureWindowStyle','docked')
run('/Users/lucas/src/codes_smarth/labbook.m')
addpath('../src/model/')
addpath('../src/common/')
addpath('../src/lib/')

%% Define the airfoil and the associated steady curve

airfoil = Airfoil('flatplate',0.15);
airfoil.r0 = 0.04;
static = load('../data/static_flatplate');
airfoil.steady = SteadyCurve(static.alpha,static.CN,14);

%% Setting up the ramps

c = [18,14,22,67,68,69,70,26,27,28,29,84,85,86,87,30,89];

for k=1:length(c)
    data = load(loadmat(LB(c(k)).ms,LB(c(k)).mpt),'raw','inert','avg','zero');
    raw = data.raw;
    if LB(c(k)).ms >= 13 && LB(c(k)).ms < 100
        inert = data.inert;
        inert.alpha = raw.alpha(raw.t>=0);
        msname = sprintf('ms%03impt%i',LB(c(k)).ms,LB(c(k)).mpt);
        assignin('base',msname,RampUpMotion('alpha',inert.alpha,'t',inert.t,'V',LB(c(k)).U));
        evalin('base',sprintf('%s.setName()',msname))
        ramp = evalin('base',msname);
        Cl = inert.Cl;
        Cd = inert.Cd;
    else
        msname = sprintf('ms%03impt%i',LB(c(k)).ms,LB(c(k)).mpt);
        assignin('base',msname,RampUpMotion('alpha',raw.alpha,'t',raw.t,'V',LB(c(k)).U));
        evalin('base',sprintf('%s.setName()',msname))
        ramp = evalin('base',msname);
        Cl = raw.Cl;
        Cd = raw.Cd;
    end
    % Butterworth filter
    fc = 35;
    fs = 1/ramp.Ts;
    [b,a] = butter(5,fc/(fs/2));
    Cl_filtered = filter(b,a,Cl);
    Cd_filtered = filter(b,a,Cd);
    ramp.setAlphaDot(LB(c(k)).alphadot) % in degrees
    % Moving average filter
    Cl_ff = movmean(Cl_filtered,30);
    Cd_ff = movmean(Cd_filtered,30);
    % Chebychev type-II filter
    fp = 1/3;
    [b,a] = cheby2(6,20,36*fp/(fs/2));    
    Cl_fff = filter(b,a,Cl_ff);
    Cd_fff = filter(b,a,Cd_ff);
    ramp.setCL(Cl);
    ramp.setCD(Cd);
    %     ramp.setCL(Cl_fff);
    %     ramp.setCD(Cd_fff);
    ramp.computeAirfoilFrame();
    ramp.isolateRamp();
    % Define stall
    ramp.findExpOnset();
    ramp.setPitchRate(airfoil);
    evalin('base',sprintf('fig%d = %s.plotCC();',k,msname));
end

%% Running Sheng experiment

% Define alpha_ds0 & compute Talpha
setLinFit(airfoil,ms012mpt1,ms010mpt1,ms013mpt1,ms025mpt1,ms025mpt2,ms025mpt3,ms025mpt4,ms014mpt1,ms014mpt2,ms014mpt3,ms014mpt4,ms034mpt1,ms034mpt2,ms034mpt3,ms034mpt4,ms015mpt1,ms116mpt1);

saveas(gcf,'../fig/alpha_ds_r','png')
% %% Add Sheng's predicted stall angles to the figures
% for k=1:length(c)
%     msname = sprintf('ms%03impt%i',LB(c(k)).ms,LB(c(k)).mpt);
%     evalin('base',sprintf('figure(fig%d)',k))
%     hold on
%     evalin('base',sprintf('plot(%s.alpha_lagonset*ones(2,1),fig%d.CurrentAxes.YLim,''b--'')',msname,k));
% end