//
//  FamilyManagementView.swift
//  Rediscover Talk
//
//  Created by Claude on 2025-08-07.
//  Family subscription management interface
//

import SwiftUI

struct FamilyManagementView: View {
    @StateObject private var familyValidator = FamilySubscriptionValidator(
        subscriptionManager: SubscriptionManager()
    )
    @State private var showingAddMember = false
    @State private var selectedMember: FamilySubscriptionValidator.FamilyMember?
    @State private var showingMemberDetails = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    familyStatusSection
                    familyMembersSection
                    familyStatsSection
                }
                .padding()
            }
            .navigationTitle("Family Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if familyValidator.canManageFamily() {
                        Button("Add Member") {
                            showingAddMember = true
                        }
                        .disabled(!familyValidator.canAddNewMember())
                    }
                }
            }
            .refreshable {
                await familyValidator.refreshFamilyStatus()
            }
        }
        .sheet(isPresented: $showingAddMember) {
            AddFamilyMemberView(familyValidator: familyValidator)
        }
        .sheet(item: $selectedMember) { member in
            FamilyMemberDetailView(member: member, familyValidator: familyValidator)
        }
        .task {
            await familyValidator.validateFamilySubscription()
        }
    }
    
    // MARK: - Family Status Section
    private var familyStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Family Subscription")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(familyValidator.familySubscriptionStatus.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if familyValidator.isValidatingFamily {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if familyValidator.familySubscriptionStatus.isActive {
                HStack(spacing: 20) {
                    StatusCard(
                        title: "Active Members",
                        value: "\(familyValidator.currentMemberCount)",
                        subtitle: "of \(familyValidator.maxFamilyMembers)",
                        color: .green
                    )
                    
                    StatusCard(
                        title: "Available Slots",
                        value: "\(familyValidator.getAvailableSlots())",
                        subtitle: "remaining",
                        color: .blue
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Family Members Section
    private var familyMembersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Family Members")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if familyValidator.canManageFamily() {
                    Button("Manage All") {
                        // Show bulk management options
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            
            if familyValidator.familyMembers.isEmpty {
                EmptyFamilyMembersView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(familyValidator.familyMembers, id: \.memberID) { member in
                        FamilyMemberRow(
                            member: member,
                            canManage: familyValidator.canManageFamily()
                        ) {
                            selectedMember = member
                            showingMemberDetails = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Family Stats Section
    private var familyStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Family Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                StatCard(
                    icon: "shareplay",
                    title: "SharePlay Sessions",
                    value: "12",
                    subtitle: "this week",
                    color: .purple
                )
                
                StatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Total Minutes",
                    value: "240",
                    subtitle: "practiced",
                    color: .green
                )
            }
            
            HStack(spacing: 12) {
                StatCard(
                    icon: "person.2.badge.plus",
                    title: "Active Members",
                    value: "\(familyValidator.getActiveFamilyMembers().count)",
                    subtitle: "this week",
                    color: .blue
                )
                
                StatCard(
                    icon: "calendar",
                    title: "Streak Days",
                    value: "7",
                    subtitle: "family goal",
                    color: .orange
                )
            }
        }
    }
}

// MARK: - Status Card
struct StatusCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

// MARK: - Family Member Row
struct FamilyMemberRow: View {
    let member: FamilySubscriptionValidator.FamilyMember
    let canManage: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Member Avatar
                Circle()
                    .fill(member.hasActiveAccess ? .green.opacity(0.2) : .gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: member.hasActiveAccess ? "person.fill" : "person.slash.fill")
                            .foregroundStyle(member.hasActiveAccess ? .green : .gray)
                    }
                
                // Member Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 4) {
                        Text(member.subscriptionSource.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if member.isActive {
                            Circle()
                                .fill(.green)
                                .frame(width: 4, height: 4)
                            
                            Text("Active")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    if let lastActive = member.lastActiveDate {
                        Text("Last active: \(lastActive, style: .relative)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Access Status
                VStack(alignment: .trailing, spacing: 2) {
                    if member.permissions.canUseSharePlay {
                        Label("SharePlay", systemImage: "shareplay")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                    
                    if member.permissions.canManageFamily {
                        Label("Organizer", systemImage: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    
                    Text("\(member.deviceInfo.count) device\(member.deviceInfo.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty Family Members View
struct EmptyFamilyMembersView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.gray)
            
            VStack(spacing: 8) {
                Text("No Family Members Yet")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("Invite family members to share your subscription and enjoy breathing sessions together.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Add Family Member View
struct AddFamilyMemberView: View {
    let familyValidator: FamilySubscriptionValidator
    @Environment(\.dismiss) private var dismiss
    @State private var inviteEmail = ""
    @State private var memberName = ""
    @State private var selectedPermissions = FamilySubscriptionValidator.MemberPermissions.fullAccess
    @State private var isSendingInvite = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Member Information") {
                    TextField("Full Name", text: $memberName)
                    TextField("Email Address", text: $inviteEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section("Permissions") {
                    Toggle("SharePlay Access", isOn: .constant(selectedPermissions.canUseSharePlay))
                    Toggle("Premium Content", isOn: .constant(selectedPermissions.canAccessPremiumContent))
                    Toggle("View Family Progress", isOn: .constant(selectedPermissions.canViewFamilyProgress))
                }
                
                Section("Invitation") {
                    Button("Send Invitation") {
                        sendInvitation()
                    }
                    .disabled(memberName.isEmpty || inviteEmail.isEmpty || isSendingInvite)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Add Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendInvitation() {
        isSendingInvite = true
        
        Task {
            // Implementation would send invitation through your backend
            try? await Task.sleep(nanoseconds: 2_000_000_000) // Simulate network delay
            
            await MainActor.run {
                isSendingInvite = false
                dismiss()
            }
        }
    }
}

// MARK: - Family Member Detail View
struct FamilyMemberDetailView: View {
    let member: FamilySubscriptionValidator.FamilyMember
    let familyValidator: FamilySubscriptionValidator
    @Environment(\.dismiss) private var dismiss
    @State private var showingRemoveConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    memberInfoSection
                    permissionsSection
                    devicesSection
                    activitySection
                    
                    if familyValidator.canManageFamily() {
                        managementSection
                    }
                }
                .padding()
            }
            .navigationTitle(member.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog("Remove Family Member", isPresented: $showingRemoveConfirmation) {
            Button("Remove Member", role: .destructive) {
                removeMember()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove \(member.displayName) from the family subscription?")
        }
    }
    
    // MARK: - Member Info Section
    private var memberInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(member.hasActiveAccess ? .green.opacity(0.2) : .gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: member.hasActiveAccess ? "person.fill" : "person.slash.fill")
                            .foregroundStyle(member.hasActiveAccess ? .green : .gray)
                            .font(.title2)
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(member.subscriptionSource.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let email = member.appleID {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Joined")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(member.joinDate, style: .date)
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Last Active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let lastActive = member.lastActiveDate {
                        Text(lastActive, style: .relative)
                            .font(.subheadline)
                    } else {
                        Text("Never")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Permissions Section
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                PermissionRow(
                    icon: "shareplay",
                    title: "SharePlay Sessions",
                    isEnabled: member.permissions.canUseSharePlay
                )
                
                PermissionRow(
                    icon: "star.fill",
                    title: "Premium Content",
                    isEnabled: member.permissions.canAccessPremiumContent
                )
                
                PermissionRow(
                    icon: "chart.bar.fill",
                    title: "Family Progress",
                    isEnabled: member.permissions.canViewFamilyProgress
                )
                
                PermissionRow(
                    icon: "gear",
                    title: "Manage Family",
                    isEnabled: member.permissions.canManageFamily
                )
            }
        }
    }
    
    // MARK: - Devices Section
    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Devices")
                .font(.headline)
                .fontWeight(.semibold)
            
            if member.deviceInfo.isEmpty {
                Text("No devices registered")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(member.deviceInfo, id: \.deviceID) { device in
                        DeviceRow(device: device)
                    }
                }
            }
        }
    }
    
    // MARK: - Activity Section
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                StatCard(
                    icon: "timer",
                    title: "Sessions",
                    value: "8",
                    subtitle: "this week",
                    color: .blue
                )
                
                StatCard(
                    icon: "clock",
                    title: "Minutes",
                    value: "45",
                    subtitle: "practiced",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Management Section
    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Management")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Button("Edit Permissions") {
                    // Show permission editing sheet
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("Remove from Family") {
                    showingRemoveConfirmation = true
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func removeMember() {
        Task {
            try? await familyValidator.removeFamilyMember(member.memberID)
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Permission Row
struct PermissionRow: View {
    let icon: String
    let title: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(isEnabled ? .blue : .gray)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isEnabled ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Device Row
struct DeviceRow: View {
    let device: FamilySubscriptionValidator.DeviceInfo
    
    var body: some View {
        HStack {
            Image(systemName: deviceIcon)
                .frame(width: 20)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.deviceName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(device.deviceType) • \(device.osVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("v\(device.appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(device.lastSeen, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var deviceIcon: String {
        switch device.deviceType.lowercased() {
        case "iphone":
            return "iphone"
        case "ipad":
            return "ipad"
        case "mac":
            return "macbook"
        case "apple tv":
            return "appletv"
        default:
            return "questionmark.diamond"
        }
    }
}

#Preview {
    FamilyManagementView()
}