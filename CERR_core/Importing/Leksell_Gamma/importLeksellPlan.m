function [planC, leksellInfo] = importLeksellPlan(planDir)
%"importLeksellPlan"
%   Imports a Leksell gamma knife plan into CERR format.  The directory
%   structure of the Leksell plan must be intact.
%
%By JRA 06/24/05
%
%LM: KRK, 05/31/07, all readLeksell<...>File functions are now complete and
%                   included in the importLeksellPlan function
%    KRK, 06/01/07, corrected the transform matrices of the scans
%    KRK, 06/04/07, added missing code in the structure import section to
%                   account for non associated scans
%    KRK, 06/05/07, added a second output variable (leksellInfo) to hold all
%                   information from the plan directory for easy access into
%                   the variables not currently used in CERR (metadata)
%    KRK, 06/07/07, the code for converting the normalized percentages in
%                   the dose matrices to units of Gy is now complete
%    KRK, 06/08/07, rescaled the imported scan images' intensities (MR only)
%                   so that they can now be viewed with the CERR CT Window
%                   preset "Head"
%    DK , 07/01/08, Rewrote the way directories are read. Change in file
%                   names and missing directories causing errors. Typo
%                   errors in converting mm to cm. Also typo error in
%                   reading CT Loop.
%
%Usage:
%   planC = importLeksellPlan(planDir)
%
% Copyright 2010, Joseph O. Deasy, on behalf of the CERR development team.
% 
% This file is part of The Computational Environment for Radiotherapy Research (CERR).
% 
% CERR development has been led by:  Aditya Apte, Divya Khullar, James Alaly, and Joseph O. Deasy.
% 
% CERR has been financially supported by the US National Institutes of Health under multiple grants.
% 
% CERR is distributed under the terms of the Lesser GNU Public License. 
% 
%     This version of CERR is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
% 
% CERR is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
% without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
% See the GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with CERR.  If not, see <http://www.gnu.org/licenses/>.

LekC = [];

files = dir(planDir);
lekSellDirStr = {files.name};

%%%%%%%%%%%%%%%%% Importing directories %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i = 1: length(lekSellDirStr)
    if files(i).isdir
        if strfind(upper(lekSellDirStr{i}), 'MR')
            LekC = readLeksellDir(planDir,'MR', LekC, lekSellDirStr{i});
        elseif strfind(lekSellDirStr{i},'CT')
            LekC = readLeksellDir(planDir,'CT', LekC, lekSellDirStr{i});
        else
            %             try
            LekC = readLeksellDir(planDir, lekSellDirStr{i}, LekC, lekSellDirStr{i});
            %             catch
            %                 disp(['No Import Options for ' lekSellDirStr{i} ' ...'])
            %                 continue
            %             end
        end
    end
end



%--------Initialize planC-------------------------------------------------%
planC   = initializeCERR;
indexS  = planC{end};
planC{indexS.CERROptions} = CERROptions;


%--------Initialize scan information--------------------------------------%
if isfield(LekC, 'mrScanS')
    for i=1:length(LekC.mrScanS)
        planC{indexS.scan}(i).scanType = LekC.mrScanS(i).scanInfo(1).scanType;
        bool = ismember({LekC.studyS.modality}, LekC.mrScanS(i).scanInfo(1).scanType);
        matches = find(bool);
        if isempty(matches)
            planC{indexS.scan}(i).transM = [];
        else
            planC{indexS.scan}(i).transM = LekC.studyS(matches(1)).rcsToxyzTransM;
        end

        planC{indexS.scan}(i).scanArray = LekC.mrScanS(i).scanArray;
        planC{indexS.scan}(i).scanInfo = LekC.mrScanS(i).scanInfo;

        planC{indexS.scan}(i).scanUID = createUID('scan');
        
        scanTypeC = {planC{indexS.scan}(i).scanInfo(:).scanType};
        matchC = strfind(upper(scanTypeC), 'COR');
        toDelete = [];
        for indMatch = 1:length(matchC)
           if ~isempty(matchC{indMatch})  && matchC{indMatch} == 1
              toDelete = [toDelete indMatch]; 
           end
        end
        
        planC{indexS.scan}(i).scanInfo(toDelete) = [];
        
        planC{indexS.scan}(i).scanArray(:,:,toDelete) = [];
                
        for indSI = 1:length(planC{indexS.scan}(i).scanInfo)
           planC{indexS.scan}(i).scanInfo(indSI).imageType = 'MR';
        end
        
    end
end

if isfield(LekC, 'ctScanS')

    for i = 1:length(LekC.ctScanS)
        indX = length(planC{indexS.scan}) + 1;
        planC{indexS.scan}(indX).scanType = LekC.ctScanS(i).scanInfo(1).scanType;

        bool = ismember({LekC.studyS.modality}, LekC.ctScanS(i).scanInfo(1).scanType);
        matches = find(bool);
        planC{indexS.scan}(indX).transM = LekC.studyS(matches(1)).rcsToxyzTransM;

        planC{indexS.scan}(indX).scanArray = LekC.ctScanS(i).scanArray;
        planC{indexS.scan}(indX).scanInfo = LekC.ctScanS(i).scanInfo;

        planC{indexS.scan}(indX).scanUID = createUID('scan');
                
        for indSI = 1:length(planC{indexS.scan}(indX).scanInfo)
           planC{indexS.scan}(indX).scanInfo(indSI).imageType = 'CT';
        end
        
    end
end

%Remove transM if importing only one scan
if length(planC{indexS.scan}) == 1
    planC{indexS.scan}(1).savedtransM.transM = planC{indexS.scan}(1).transM;
    planC{indexS.scan}(1).savedtransM.name = 'GammaKnifeImport';
    planC{indexS.scan}(1).transM = [];
end

%Set the uniformized scan data in the plan (planC{indexS.scan})
planC = setUniformizedData(planC);
%The original transformation matrices read in by the readLeksellStudy
%function contained scaling as well as transformation/rotation.  Since CERR
%is compatible with only transformation/rotation matrices and scales
%according to its 3 voxel sizes, the scaling needs to be removed from the
%current transformation matrices.  To do this, multiply the original transM
%by the inverse of the pure scaling matrix (multiplied by 10 since the
%voxel sizes are in cm and must be mm).
for i=1:length(planC{indexS.scan})
    if ~isempty(planC{indexS.scan}(i).transM)
        planC{indexS.scan}(i).transM = planC{indexS.scan}(i).transM / [planC{indexS.scan}(i).uniformScanInfo.grid1Units*10 0 0 0; 0 planC{indexS.scan}(i).uniformScanInfo.grid2Units*10 0 0; 0 0 planC{indexS.scan}(i).uniformScanInfo.sliceThickness*10 0; 0 0 0 1];
        planC{indexS.scan}(i).transM(3,4) = planC{indexS.scan}(i).transM(3,4) - planC{indexS.scan}(i).uniformScanInfo.firstZValue;
    end
end


%-----------------Load structure(s)---------------------------------------%
structNum = 1;
nonAssocCounter = 0;
for i=1:length(LekC.volS)
    %Check if the scan is either MR or CT, if not, disregard
    regTo = LekC.volS(i).registeredTo;
    bool = ismember({planC{indexS.scan}.scanType}, regTo);
    associatedScan = find(bool);
    if isempty(associatedScan)
        %Continue if not associated with any scan, eg Leksell Skull.
        nonAssocCounter = nonAssocCounter + 1; %keep a count of the non associated scans to index associated scans correctly
        continue;
    end

    %Check for contours done on fused images (slicenums are therefore out of
    %the range CT and MR images).  There may be a way to map these fusion
    %contours to MR or CT, possibly using the information from
    %LekC.fusionS, but it hasn't been completed yet.
    fusionContour = 0;
    for j=1:length(LekC.volS(i).contour)
        for k=1:length(planC{indexS.scan})
            if(LekC.volS(i).contour(j).sliceNum > length(planC{indexS.scan}(k).scanInfo))
                fusionContour = 1;
                break;
            end
        end
    end
    if(fusionContour ~= 0)
        nonAssocCounter = nonAssocCounter + 1;
        continue;
    end

    %After checking if its associated, put in the structure information
    newStructS = newCERRStructure(associatedScan, planC);
    planC{indexS.structures} = dissimilarInsert(planC{indexS.structures},newStructS,i - nonAssocCounter);
    planC{indexS.structures}(i - nonAssocCounter).structureName = LekC.volS(i).structName;
    contour = LekC.volS(i).contour;
    for j=1:length(contour)
        sliceNum = contour(j).sliceNum + 1; %+ 1 to match Matlab's indexing (1-n+1 rather than 0-n)
        %scale the xy points based on the voxel sizes
        xyPoints = contour(j).contour;
        xyPoints(:,1) = planC{indexS.scan}(associatedScan).uniformScanInfo.grid1Units * contour(j).contour(:,1);
        xyPoints(:,2) = planC{indexS.scan}(associatedScan).uniformScanInfo.grid2Units * contour(j).contour(:,2);
        %set z values for the current x,y vertices
        xyPoints = [xyPoints ones(size(xyPoints(:,1)))*planC{indexS.scan}(associatedScan).scanInfo(sliceNum).zValue];
        %store the xyz points of each vertex
        planC{indexS.structures}(i - nonAssocCounter).contour(sliceNum).segments.points = xyPoints;
    end
    structNum = structNum + 1; %keep a count of all of the associated structures
    planC{indexS.structures}(i - nonAssocCounter).strUID = createUID('structure');
    planC{indexS.structures}(i - nonAssocCounter).assocScanUID = planC{indexS.scan}(associatedScan).scanUID;

    %Remove the contours from the second return variable to save space.
    %Only do this if the contour is read into CERR. In other words, don't
    %remove the contours from this return variable if they are from a non
    %associated scan (any contour not done on MR or CT, ex: fused).
    LekC.volS(i).contour = [];
end
%Calculate how to display the contoured segments inside of CERR
planC = getRasterSegs(planC);


%------------Load dose information----------------------------------------%
normalizingConst = -1; %used to find the global maximum normalizing constant in the dose matrix (see readLeksellDoseGroupFile for more information)
%Put dose info into the CERR data structure.

if isfield(LekC,'shotS')
    for i=1:length(LekC.shotS.doseMatrixInfo)
        dMI = LekC.shotS.doseMatrixInfo(i);

        planC{indexS.dose}(i).fractionGroupID = dMI.name;
        planC{indexS.dose}(i).horizontalGridInterval = dMI.gridSize;
        planC{indexS.dose}(i).verticalGridInterval = dMI.gridSize;
        planC{indexS.dose}(i).depthGridInterval = dMI.gridSize;

        try
            planC{indexS.dose}(i).doseArray = LekC.doses{i};
        catch
            planC{indexS.dose}(i) = [];
            continue
        end

        % Temporarily hold the max of each dose matrix to see if it is larger
        % than the other dose matrices' max value. If it is, store the new
        % larger value in normalizingConst (this only affects plans with multiple DMs).
        tmpNorm = max(planC{indexS.dose}(i).doseArray(:));
        if(tmpNorm > normalizingConst)
            normalizingConst = tmpNorm;
        end

        planC{indexS.dose}(i).coord1OFFirstPoint = LekC.shotS.doseMatrixInfo(i).minExtent(1);
        planC{indexS.dose}(i).coord2OFFirstPoint = LekC.shotS.doseMatrixInfo(i).minExtent(2);
        planC{indexS.dose}(i).coord3OfFirstPoint = LekC.shotS.doseMatrixInfo(i).minExtent(3);

        siz = size(planC{indexS.dose}(i).doseArray);
        planC{indexS.dose}(i).sizeOfDimension1 = siz(2);
        planC{indexS.dose}(i).sizeOfDimension2 = siz(1);
        planC{indexS.dose}(i).sizeOfDimension3 = siz(3);

        planC{indexS.dose}(i).zValues = linspace(LekC.shotS.doseMatrixInfo(i).minExtent(3), LekC.shotS.doseMatrixInfo(i).maxExtent(3), siz(3));

        planC{indexS.dose}(i).doseUID = createUID('dose');
        planC{indexS.dose}(i).doseUnits = 'Gy';
        planC{indexS.dose}(i).assocScanUID = [];
    end
end
%Normalize the dose arrays and convert them to Gy using previously found max.
%This converts all dose matrix values into CERR's native radiation units, Gy.
for i=1:length(planC{indexS.dose})
    planC{indexS.dose}(i).doseArray = (LekC.superS.globalMaxDose)*(planC{indexS.dose}(i).doseArray)/normalizingConst;
end

%Log end of import


%-------------------Store metadata----------------------------------------%
%Put all information obtained from the readLeksell<...>File functions into
%the other return variable to view and/or possibly incorporate into CERR.
%Also, get rid of some of the larger pieces of data (doses, pixel arrays)
%that have already been read into the CERR variable to save space.  See the
%"Load Structures" section of this function to see how the contours are
%removed from this variable.

LekC.doses = [];
try
    for i=1:length(LekC.ctScanS)
        LekC.ctScanS(i).scanArray = [];
    end
end
try
    for i=1:length(LekC.mrScanS)
        LekC.mrScanS(i).scanArray = [];
    end
end
leksellInfo = LekC;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%% READ THE DIRECTORY STRUCTURE OF LEKSELL %%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function LekC = readLeksellDir(planDir,dirName, LekC, mrctdir)

switch dirName

    case 'Fusions'
        %Get Fusion info. (not used in CERR currently)
        disp('Reading Fusion info...')
        % fusionsFilename = fullfile(planDir, 'Fusions', 'Fusion.1');
        fusionsFilename = getLeksellFilesNames(fullfile(planDir, 'Fusions'), 'Fusion');
        for i = 1:length(fusionsFilename)
            LekC(i).fusionS = readLeksellFusionFile(fullfile(planDir, 'Fusions', fusionsFilename{i}));
        end

    case 'Orientations'
        %Get Orientations info. (not used in CERR currently)
        disp('Reading Orientations info...')
        % oriFilename = fullfile(planDir, 'Orientations', 'Orientation.1');
        oriFilename = getLeksellFilesNames(fullfile(planDir, 'Orientations'), 'Orientation');
        for i = 1:length(oriFilename)
            LekC(i).oriS = readLeksellOrientationFile(fullfile(planDir, 'Orientations', oriFilename{i}));
        end

    case 'SRdata'
        %Get Dosegroup data.
        disp('Reading Dosegroup info...')
        % doseFilename = fullfile(planDir, 'SRdata', ['DoseGroup' num2str(doseNum) '.1']);

        doseFilename = getLeksellFilesNames(fullfile(planDir, 'SRdata'), 'DoseGroup');

        for i = 1:length(doseFilename)
            LekC.doses{i} = readLeksellDoseGroupFile(fullfile(planDir, 'SRdata', doseFilename{i}));
        end

        %Get skull info. (not used in CERR currently)
        disp('Reading Skull info...')
        % skullFilename = fullfile(planDir, 'SRdata', 'Skull.1');
        skullFilename = getLeksellFilesNames(fullfile(planDir, 'SRdata'), 'Skull');
        for i = 1:length(skullFilename)
            LekC(i).skullS = readLeksellSkullFile(fullfile(planDir, 'SRdata', skullFilename{i}));
        end

        %Get super info.
        disp('Reading Super info...')

        % superFilename = fullfile(planDir, 'SRdata', 'Super.1');
        superFilename = getLeksellFilesNames(fullfile(planDir, 'SRdata'), 'Super');
        for i = 1:length(superFilename )
            LekC(i).superS = readLeksellSuperFile(fullfile(planDir, 'SRdata', superFilename{i}));
        end

        %Get target frame info. (not used in CERR currently)
        disp('Reading TargetFrame info...')
        % targetframeFilename = fullfile(planDir, 'SRdata', 'TargetFrame.1');
        targetframeFilename = getLeksellFilesNames(fullfile(planDir, 'SRdata'), 'TargetFrame');
        for i = 1:length(targetframeFilename)
            LekC(i).targetframeS = readLeksellTargetframeFile(fullfile(planDir, 'SRdata', targetframeFilename{i}));
        end


    case 'Shots'
        %Get the shot info.
        disp('Reading Shot info...')

        % shotFilename = fullfile(planDir, 'Shots', 'Shot.1');
        shotFilename = getLeksellFilesNames(fullfile(planDir, 'Shots'), 'Shot');

        if isempty(shotFilename)
            shotFilename = getLeksellFilesNames(fullfile(planDir, 'Shots'), 'Group');
        end
        
        for i = 1:length(shotFilename)
            LekC(i).shotS = readLeksellShotsFile(fullfile(planDir, 'Shots', shotFilename{i}));
        end

    case 'Studyregs'
        %Get the studyReg info. (not used in CERR currently)
        disp('Reading StudyReg info...')
        % srFilename = fullfile(planDir, 'Studyregs', 'Studyreg.1');
        srFilename = getLeksellFilesNames(fullfile(planDir, 'Studyregs'), 'studyreg');
        for i = 1:length(srFilename)
            LekC(i).studyRegS = readLeksellStudyregFile(fullfile(planDir, 'Studyregs', srFilename{i}));
        end

    case 'Studys'
        %Get the study info.
        disp('Reading Study info...')
        % studyFilename = fullfile(planDir, 'Studys', 'Study.1');
        studyFilename = getLeksellFilesNames(fullfile(planDir, 'Studys'), 'Study');
        for i = 1:length(studyFilename)
            LekC(i).studyS = readLeksellStudyFile(fullfile(planDir, 'Studys', studyFilename{i}));
        end

    case 'Volumes'
        %Get volume info.
        disp('Reading Volume info...')
        % volFilename = fullfile(planDir, 'Volumes', 'Volume.1');
        volFilename  = getLeksellFilesNames(fullfile(planDir, 'Volumes'), 'Volume');
        for i = 1:length(volFilename)
            LekC(i).volS = readLeksellVolumeFile(fullfile(planDir, 'Volumes', volFilename{i}));
        end

    case 'Plugs'
        %Get plug info. (not used in CERR currently)
        disp('Reading Plug info...')

        % plugFilename = fullfile(planDir, 'Plugs', 'Plug.1');
        plugFilename = getLeksellFilesNames(fullfile(planDir, 'Plugs'), 'Plug');
        for i = 1:length(plugFilename)
            LekC(i).plugS = readLeksellPlugFile(fullfile(planDir, 'Plugs', plugFilename{i}));
        end

    case 'Sortings'
        %Get sorting info. (not used in CERR currently)
        disp('Reading Sorting info...')
        % sortingFilename = fullfile(planDir, 'Sortings', 'Sorting.1');
        sortingFilename = getLeksellFilesNames(fullfile(planDir, 'Sortings'), 'Sorting');
        for i = 1:length(sortingFilename)
            LekC(i).sortingS = readLeksellSortingFile(fullfile(planDir, 'Sortings', sortingFilename{i}));
        end

    case 'Thresholds'
        %Get threshold info. (not used in CERR currently)
        disp('Reading Threshold info...')
        % thresholdFilename = fullfile(planDir, 'Thresholds', 'Threshold.1');
        thresholdFilename = getLeksellFilesNames(fullfile(planDir, 'Thresholds'), 'Threshold');
        for i = 1:length(thresholdFilename)
            LekC(i).thresholdS = readLeksellThresholdFile(fullfile(planDir, 'Thresholds', thresholdFilename{i}));
        end

    case 'MR'
        disp('Reading MR scan info...')

        if isfield(LekC,'mrScanS')
            indX = length(LekC.mrScanS) + 1;
        else
            indX = 1;
        end

        imageDir = fullfile(planDir, mrctdir);
        [mat, scanInfo] = readLeksellImageset(imageDir,'MR');
        if isempty(mat)
            return
        end
        LekC.mrScanS(indX).scanArray = mat;
        LekC.mrScanS(indX).scanInfo = scanInfo;
        %Put the pixel intensities in the range of 1000-1700. This code works, but
        %is not generally correct.  Modify the commented code under this to correct
        %the MR pixel intensity problem.
        %LekC.mrScanS(indX).scanArray = LekC.mrScanS(indX).scanArray - median(LekC.mrScanS(indX).scanArray(:)) + 1000;
        LekC.mrScanS(indX).scanArray = LekC.mrScanS(indX).scanArray; % - median(LekC.mrScanS(indX).scanArray(:)) + 1000;
        %Match the scan to the study, then subtract the lower of the ranges to
        %standardize the pixel intensity ranges (make it go from 0-722 rather than
        %its original values in the range of 32000-33000).
        %    for j=1:length(LekC.studyS)
        %        if(strmatch(LekC.studyS(j).modality, LekC.mrScanS(indX).scanInfo(1).scanType))
        %            LekC.mrScanS(indX).scanArray = LekC.mrScanS(indX).scanArray -
        %            LekC.studyS(j).pixelIntensityRange(1);
        %            break;
        %        end
        %    end

    case 'CT'
        if isfield(LekC,'ctScanS')
            indX = length(LekC.ctScanS) + 1;
        else
            indX = 1;
        end
        disp('Reading CT scan info...')

        imageDir = fullfile(planDir, mrctdir);

        [mat, scanInfo] = readLeksellImageset(imageDir,'CT');
        if isempty(mat)
            return
        end

        LekC.ctScanS(indX).scanInfo = scanInfo;

        LekC.ctScanS(indX).scanArray = mat;
end