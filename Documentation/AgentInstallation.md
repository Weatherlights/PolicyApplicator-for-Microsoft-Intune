# Agent Installation Guide

This short guide will show you how to deploy the PolicyApplicator Agent.

## Get the Agent

You can download the latest release from <a href="https://github.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/releases">here</a>.

Choose the MSI file if you prefer to deploy the agent using LoB or the EXE if you prefer to deploy it using the Win32 App mechanismen.

## MSI: Create a LoB App

So if you go for the MSI file everything you need to do is pretty straight forward:

1. Create a new app and select the app type to Line-of-business app.
<img src="https://github.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/blob/aa4a836e6c88106168a53141bea0fb42a630bd34/Documentation/Img/step1%20createapp.png" alt="Step1"/>

2. Click Browse to search for the MSI file
<img src="https://github.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/blob/aa4a836e6c88106168a53141bea0fb42a630bd34/Documentation/Img/step2%20Browse.png" alt="Step2"/>
... and select it.
<img src="https://github.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/blob/aa4a836e6c88106168a53141bea0fb42a630bd34/Documentation/Img/step3%20PickFile.png" alt="Step21"/>


3. Enter the missing values in the form.
<img src="https://github.com/Weatherlights/PolicyApplicator-for-Microsoft-Intune/blob/aa4a836e6c88106168a53141bea0fb42a630bd34/Documentation/Img/step4%20FillinEverything.png" alt="Step1"/>

4. Click next and assign the app as you prefer.

5. Click next and finish to deploy the app.

That is it :). Now the agent get's installed.
