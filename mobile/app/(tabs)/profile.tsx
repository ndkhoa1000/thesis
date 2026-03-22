import { View, Text, TouchableOpacity, Alert, ScrollView, TextInput, ActivityIndicator } from 'react-native';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/lib/supabase';
import { Tables } from '@/lib/database.types';
import { useEffect, useState } from 'react';

export default function ProfileScreen() {
  const { user, signOut } = useAuth();
  const [profile, setProfile] = useState<Tables<'profiles'> | null>(null);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (user) fetchProfile();
  }, [user]);

  const fetchProfile = async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user!.id)
      .single();

    if (!error && data) {
      setProfile(data);
      setFullName(data.full_name || '');
      setPhone(data.phone || '');
    }
    setLoading(false);
  };

  const handleSave = async () => {
    if (!user) return;
    setSaving(true);
    const { error } = await supabase
      .from('profiles')
      .update({ full_name: fullName, phone })
      .eq('id', user.id);

    if (error) {
      Alert.alert('Lỗi', 'Không thể cập nhật thông tin');
    } else {
      setEditing(false);
      fetchProfile();
    }
    setSaving(false);
  };

  const handleSignOut = () => {
    Alert.alert('Đăng xuất', 'Bạn có chắc muốn đăng xuất?', [
      { text: 'Huỷ', style: 'cancel' },
      { text: 'Đăng xuất', style: 'destructive', onPress: signOut },
    ]);
  };

  const roleLabels: Record<string, string> = {
    DRIVER: 'Tài xế',
    ATTENDANT: 'Nhân viên',
    MANAGER: 'Quản lý bãi xe',
    LOT_OWNER: 'Chủ bãi xe',
    ADMIN: 'Quản trị viên',
  };

  if (loading) {
    return (
      <View className="flex-1 bg-slate-50 dark:bg-slate-900 items-center justify-center">
        <ActivityIndicator size="large" color="#0ea5e9" />
      </View>
    );
  }

  return (
    <ScrollView className="flex-1 bg-slate-50 dark:bg-slate-900">
      {/* Profile Header */}
      <View className="items-center pt-8 pb-6">
        <View className="w-20 h-20 rounded-full bg-primary-100 dark:bg-primary-900 items-center justify-center mb-3">
          <Text className="text-3xl">👤</Text>
        </View>
        <Text className="text-lg font-semibold text-slate-900 dark:text-white">
          {profile?.full_name || user?.email}
        </Text>
        <Text className="text-sm text-primary-500 mt-1">
          {roleLabels[profile?.role || 'DRIVER']}
        </Text>
        <Text className="text-xs text-slate-400 mt-0.5">{user?.email}</Text>
      </View>

      {/* Profile Info / Edit */}
      <View className="px-5 gap-3">
        <Text className="text-base font-semibold text-slate-800 dark:text-slate-200">
          Thông tin cá nhân
        </Text>

        {editing ? (
          <>
            <View>
              <Text className="text-sm text-slate-500 dark:text-slate-400 mb-1">Họ tên</Text>
              <TextInput
                className="h-12 px-4 rounded-xl bg-white dark:bg-slate-800 text-base text-slate-900 dark:text-white border border-slate-200 dark:border-slate-700"
                value={fullName}
                onChangeText={setFullName}
                placeholder="Nhập họ tên"
                placeholderTextColor="#94a3b8"
              />
            </View>
            <View>
              <Text className="text-sm text-slate-500 dark:text-slate-400 mb-1">Số điện thoại</Text>
              <TextInput
                className="h-12 px-4 rounded-xl bg-white dark:bg-slate-800 text-base text-slate-900 dark:text-white border border-slate-200 dark:border-slate-700"
                value={phone}
                onChangeText={setPhone}
                placeholder="0912 345 678"
                placeholderTextColor="#94a3b8"
                keyboardType="phone-pad"
              />
            </View>
            <View className="flex-row gap-3 mt-2">
              <TouchableOpacity
                className="flex-1 h-11 rounded-xl bg-slate-200 dark:bg-slate-700 items-center justify-center"
                onPress={() => setEditing(false)}
              >
                <Text className="text-slate-700 dark:text-slate-300 font-medium">Huỷ</Text>
              </TouchableOpacity>
              <TouchableOpacity
                className="flex-1 h-11 rounded-xl bg-primary-500 items-center justify-center"
                onPress={handleSave}
                disabled={saving}
              >
                {saving ? (
                  <ActivityIndicator color="white" size="small" />
                ) : (
                  <Text className="text-white font-semibold">Lưu</Text>
                )}
              </TouchableOpacity>
            </View>
          </>
        ) : (
          <>
            <View className="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
              <View className="flex-row justify-between mb-3">
                <Text className="text-sm text-slate-500 dark:text-slate-400">Họ tên</Text>
                <Text className="text-sm font-medium text-slate-800 dark:text-slate-200">
                  {profile?.full_name || 'Chưa cập nhật'}
                </Text>
              </View>
              <View className="flex-row justify-between mb-3">
                <Text className="text-sm text-slate-500 dark:text-slate-400">Số điện thoại</Text>
                <Text className="text-sm font-medium text-slate-800 dark:text-slate-200">
                  {profile?.phone || 'Chưa cập nhật'}
                </Text>
              </View>
              <View className="flex-row justify-between">
                <Text className="text-sm text-slate-500 dark:text-slate-400">Vai trò</Text>
                <Text className="text-sm font-medium text-primary-500">
                  {roleLabels[profile?.role || 'DRIVER']}
                </Text>
              </View>
            </View>
            <TouchableOpacity
              className="h-11 rounded-xl bg-primary-50 dark:bg-primary-900/30 items-center justify-center border border-primary-200 dark:border-primary-800"
              onPress={() => setEditing(true)}
            >
              <Text className="text-primary-600 dark:text-primary-400 font-semibold">Chỉnh sửa</Text>
            </TouchableOpacity>
          </>
        )}
      </View>

      {/* Menu Items */}
      <View className="px-5 gap-2 mt-6">
        <Text className="text-base font-semibold text-slate-800 dark:text-slate-200 mb-1">
          Tiện ích
        </Text>
        <TouchableOpacity className="bg-white dark:bg-slate-800 rounded-xl p-4 flex-row items-center border border-slate-200 dark:border-slate-700">
          <Text className="text-xl mr-3">🚗</Text>
          <Text className="flex-1 text-slate-800 dark:text-slate-200 font-medium">Xe của tôi</Text>
          <Text className="text-slate-400">›</Text>
        </TouchableOpacity>

        <TouchableOpacity className="bg-white dark:bg-slate-800 rounded-xl p-4 flex-row items-center border border-slate-200 dark:border-slate-700">
          <Text className="text-xl mr-3">🎫</Text>
          <Text className="flex-1 text-slate-800 dark:text-slate-200 font-medium">Vé tháng</Text>
          <Text className="text-slate-400">›</Text>
        </TouchableOpacity>

        <TouchableOpacity className="bg-white dark:bg-slate-800 rounded-xl p-4 flex-row items-center border border-slate-200 dark:border-slate-700">
          <Text className="text-xl mr-3">💳</Text>
          <Text className="flex-1 text-slate-800 dark:text-slate-200 font-medium">Thanh toán</Text>
          <Text className="text-slate-400">›</Text>
        </TouchableOpacity>
      </View>

      {/* Sign Out */}
      <View className="px-5 mt-6 mb-8">
        <TouchableOpacity
          className="bg-red-50 dark:bg-red-950 rounded-xl p-4 items-center border border-red-200 dark:border-red-800"
          onPress={handleSignOut}
        >
          <Text className="text-red-600 dark:text-red-400 font-semibold">Đăng xuất</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}
