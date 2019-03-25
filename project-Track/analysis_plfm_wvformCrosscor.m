function analysis_plfm_wvformCrosscor
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% waveform calculates crosscorreslation of waveforms of spontaneous spikes
% and those of light evoked spikes. mat-files in the folder are calculated.
% 
% pre-stm, and post-stm are used for baseline spike waveforms
% Designed only for platform comparison
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

lightwin = [0 20]; % ms
sponwin = [-70 0];

% Load mat-files in the folder
mList = mLoad;
nCell = length(mList);

[cFile, ntFile, tFile] = deal(cell(nCell,1));
for iC = 1:nCell
    idCell = strsplit(mList{iC},'_');
    idCell = length(idCell{end});
    switch idCell
        case 5
            preext1 = '.mat';
            preext2 = '_\d.mat';
            curext1 = '.clusters';
            curext2 = '.ntt';
            curext3 = '.t';
            cFile{iC} = regexprep(mList{iC},preext2,curext1);
            ntFile{iC} = regexprep(mList{iC},preext2,curext2);
            tFile{iC} = regexprep(mList{iC},preext1,curext3);
%             tFile{iC} = cellfun(@(x) regexprep(x,preext1,curext3), mList{iC}, 'UniformOutput',false);
%             cFile{iC} = cellfun(@(x) regexprep(x,preext2,curext1), mList{iC}, 'UniformOutput',false);
%             ntFile{iC} = cellfun(@(x) regexprep(x,preext2,curext2), mList{iC}, 'UniformOutput',false);
        case 6 % clusters bigger than 9
            preext1 = '.mat';
            preext2 = '_\d\d.mat';
            curext1 = '.clusters';
            curext2 = '.ntt';
            curext3 = '.t';
            cFile{iC} = regexprep(mList{iC},preext2,curext1);
            ntFile{iC} = regexprep(mList{iC},preext2,curext2);
            tFile{iC} = regexprep(mList{iC},preext1,curext3);
    end
end    
eFile = cellfun(@(x) [fileparts(x),'\Events.mat'], mList, 'UniformOutput',false);

[m_spont_wv, m_evoked_wv] = deal(cell(1, 4));
for iTT = 1:4
    m_spont_wv{iTT} = zeros(1, 32);
    m_evoked_wv{iTT} = zeros(1, 32);
end

for iCell = 1:nCell
    % Load waveform of single cluster
    [cellPath,cellName,~] = fileparts(mList{iCell});
    disp(['### Waveform Crosscor analysis: ',mList{iCell},'...']);
    ttname = regexp(cellName,'_','split');
    
    load(cFile{iCell},'-mat','MClust_Clusters');
    spk_idx = FindInCluster(MClust_Clusters{str2num(ttname{2})});
    [~,wv] = LoadTT_NeuralynxNT(ntFile{iCell});
    
    cellwv = wv(spk_idx,:,:);
    
    % Get input range
    nttfile = fopen(ntFile{iCell});
    
    volts = fgetl(nttfile);
    while ~strncmp(volts,'-ADBitVolts',11)
        volts = fgetl(nttfile);
    end
    volttemp = strsplit(volts,' ');
    bitvolt = zeros(1,4);
    for ich = 1:4
        bitvolt(ich) = str2num(volttemp{ich+1});
    end
    fclose(nttfile);
    
    % Find highest peak channel
    load([cellPath,'\',ttname{1},'_Peak.fd'],'-mat', 'FeatureData');
    [~,maintt] = max(mean(FeatureData(spk_idx,:)));
    
    % Load tFiles and spike time
    [tData,~] = tLoad;
    nspike = length(tData{iCell});
    
    % Load light time
    load(eFile{iCell}, 'lightTime');
    lighttime = lightTime.Plfm8hz;
    nT = length(lighttime);
    
    % Find spike within the range of light stimulation
    spont_idx = zeros(nspike,1);
    evoked_idx = zeros(nspike,1);
    for iT = 1:nT
        [~,spont_temp] = histc(tData{iCell},lighttime(iT)+sponwin);
        [~,evoked_temp] = histc(tData{iCell},lighttime(iT)+lightwin);
        spont_idx(spont_temp==1) = 1;
        evoked_idx(find(evoked_temp==1, 1, 'first')) = 1;
    end
    
    % Get mean waveform
    spont_wv = cellwv(logical(spont_idx),:,:);
    evoked_wv = cellwv(logical(evoked_idx),:,:);
    
    for iTT = 1:4
        m_spont_wv{iTT} = (10^6)*bitvolt(iTT)*squeeze(mean(spont_wv(:,iTT,:),1));
        m_evoked_wv{iTT} = (10^6)*bitvolt(iTT)*squeeze(mean(evoked_wv(:,iTT,:),1));
    end
    
    if sum(double(spont_idx))==0 || sum(double(evoked_idx))==0
        r_wv = NaN;
    else
        rtemp = corrcoef(m_spont_wv{maintt}',m_evoked_wv{maintt}');  
        r_wv = rtemp(1,2);
    end
    wv_maintt = maintt;
    save([cellName,'.mat'],'r_wv','m_spont_wv','m_evoked_wv','wv_maintt','-append');
end
disp('### waveform correlation analysis is done!');