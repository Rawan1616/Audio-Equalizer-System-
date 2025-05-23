filename = input('Please enter the name of the audio file: ', 's');
[audio, sampleRate] = audioread(filename);
orignal=audio;
Total=0;
freq_rang = [0, 200, 400, 800, 1200, 3000, 6000, 12000, 15000, 20000];

gains = zeros(1, 10);

disp('Please enter the gain for each freq range:');

 for i = 1:9
           prompt = sprintf('Enter gain in db for %d-%d Hz: ', freq_rang(i), freq_rang(i+1));
          % gains(i) = db2pow(input(prompt)); 
           gains(i) = input(prompt);

 end
           
 O_Sample_R = sprintf('Enter output sample rate (orignal Fs = %d): ',sampleRate);
O_Sample_R=input(O_Sample_R);
if O_Sample_R < sampleRate
    x=sampleRate/O_Sample_R;
    audio = resample(audio, ceil(sampleRate*x), sampleRate);
    O_Sample_R = sampleRate;
elseif O_Sample_R > sampleRate
    x=O_Sample_R/sampleRate;
    audio = resample(audio, ceil(sampleRate/x), sampleRate);
    O_Sample_R = sampleRate;
end
half_Sam_Rate = O_Sample_R / 2;

while true
    disp('1) IIR Filter');
    disp('2) FIR Filter');
    filterType = input('Please choose the type of filter:');
    
    switch filterType
        case 1
            Order = input('Please enter your order: ');
             
            for i = 1:9
                
                if i==1
                    cutoffFreq1 = freq_rang(i+1) / half_Sam_Rate;
                    [numerator, denominator] = butter(Order, cutoffFreq1);
                else 
                    cutoffFreq1 = freq_rang(i) / half_Sam_Rate;
                    cutoffFreq2 = freq_rang(i+1) / half_Sam_Rate;
                    [numerator, denominator] = butter(Order, [cutoffFreq1,cutoffFreq2]);
                end
                
                TF = tf(numerator, denominator);
                TF = TF * gains(i);
                After_Fliter = filter(numerator, denominator, audio) * gains(i);
                Total=Total+After_Fliter;
                [mag, freq] = freqz(numerator, denominator);
                magResponse = abs(mag);
                phaseResponse = angle(mag) * 180 / pi;
                
                
                figure;
                subplot(4, 1, 1); plot(freq/pi, magResponse); grid; xlim([0 1]); title('mag');
                subplot(4, 1, 2); plot(freq/pi, phaseResponse); grid; xlim([0 0.1]); title('Phase');
                subplot(4, 1, 3); plot(impulse(TF)); grid; title('Impulse Response');
                subplot(4, 1, 4); plot(step(TF)); grid; title('Step Response');
               
                figure; pzmap(TF); title(sprintf('Zeros and poles of (%d-%d Hz)', freq_rang(i), freq_rang(i+1)));
                
            end

            break;
        case 2
            Order = input('enter your order: ');
            for i = 1:9
                
                if i==1
                    cutoffFreq1 = freq_rang(i+1) / half_Sam_Rate;
                    filter_coef = fir1(Order, cutoffFreq1);
                else 
                    cutoffFreq1 = freq_rang(i) / half_Sam_Rate;
                    cutoffFreq2 = freq_rang(i+1) / half_Sam_Rate;
                    filter_coef = fir1(Order, [cutoffFreq1,cutoffFreq2]);
                end
                
                After_Fliter = filter(filter_coef, 1, audio)* gains(i);
                filter_coef = filter_coef * gains(i);
                Total=Total+After_Fliter;
                [mag, freq] = freqz(filter_coef, 1);
                magResponse = abs(mag);
                phaseResponse = angle(mag) * 180 / pi;

                figure;
                subplot(4, 1, 1); plot(freq/pi, magResponse); grid; xlim([0 1]); title('mag');
                subplot(4, 1, 2); plot(freq/pi, phaseResponse); grid; xlim([0 0.1]); title('Phase');
                subplot(4, 1, 3); plot(impz(filter_coef)); grid; title('Impulse Response');
                subplot(4, 1, 4); plot(stepz(filter_coef)); grid; title('Step Response');
               
            end
            break;

        otherwise
            disp('Please try again.');
    end
end


Total=Total/max(abs(Total));

outputFilename = sprintf('filtered_%s.wav', filename);
audiowrite(outputFilename, Total, O_Sample_R);

disp('Filtered audio saved successfully as filteretestd_"fliename".wav');

figure;subplot(2,1,1);plot(orignal);title('orignal Signal');
subplot(2,1,2);plot(Total);title('New Signal');

forignal=linspace(-sampleRate/2,sampleRate,length(abs(fftshift(fft(orignal)))));
fnew=linspace(-O_Sample_R/2,O_Sample_R,length(abs(fftshift(fft(Total)))));

figure;subplot(2,1,1);plot(forignal,abs(fftshift(fft(orignal))));title('orignal Signal');
subplot(2,1,2);plot(fnew,abs(fftshift(fft(Total))));title('New Signal');