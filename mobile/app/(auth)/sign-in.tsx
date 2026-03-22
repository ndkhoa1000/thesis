import { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  KeyboardAvoidingView,
  Platform,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { Link } from 'expo-router';
import { useAuth } from '@/contexts/AuthContext';

export default function SignInScreen() {
  const { signIn } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSignIn = async () => {
    if (!email || !password) {
      Alert.alert('Lỗi', 'Vui lòng nhập email và mật khẩu');
      return;
    }

    setLoading(true);
    const { error } = await signIn(email, password);
    setLoading(false);

    if (error) {
      Alert.alert('Đăng nhập thất bại', error.message);
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      className="flex-1 bg-white dark:bg-slate-900"
    >
      <View className="flex-1 justify-center px-8">
        {/* Header */}
        <View className="items-center mb-10">
          <Text className="text-4xl font-bold text-primary-500 mb-2">🅿️ ParkSmart</Text>
          <Text className="text-base text-slate-500 dark:text-slate-400">
            Quản lý bãi xe thông minh
          </Text>
        </View>

        {/* Form */}
        <View className="gap-4">
          <View>
            <Text className="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Email
            </Text>
            <TextInput
              className="h-12 px-4 rounded-xl bg-slate-100 dark:bg-slate-800 text-base text-slate-900 dark:text-white"
              placeholder="you@example.com"
              placeholderTextColor="#94a3b8"
              value={email}
              onChangeText={setEmail}
              autoCapitalize="none"
              keyboardType="email-address"
            />
          </View>

          <View>
            <Text className="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Mật khẩu
            </Text>
            <TextInput
              className="h-12 px-4 rounded-xl bg-slate-100 dark:bg-slate-800 text-base text-slate-900 dark:text-white"
              placeholder="••••••••"
              placeholderTextColor="#94a3b8"
              value={password}
              onChangeText={setPassword}
              secureTextEntry
            />
          </View>

          <TouchableOpacity
            className="h-12 rounded-xl bg-primary-500 items-center justify-center mt-2"
            onPress={handleSignIn}
            disabled={loading}
            activeOpacity={0.8}
          >
            {loading ? (
              <ActivityIndicator color="white" />
            ) : (
              <Text className="text-white text-base font-semibold">Đăng nhập</Text>
            )}
          </TouchableOpacity>
        </View>

        {/* Footer */}
        <View className="flex-row justify-center mt-6">
          <Text className="text-slate-500 dark:text-slate-400">Chưa có tài khoản? </Text>
          <Link href="/(auth)/sign-up" asChild>
            <TouchableOpacity>
              <Text className="text-primary-500 font-semibold">Đăng ký</Text>
            </TouchableOpacity>
          </Link>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}
