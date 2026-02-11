import api from './api';

const profileService = {
  // Lấy tất cả profiles
  getAll: async () => {
    const response = await api.get('/profiles');
    return response.data;
  },

  // Lấy 1 profile theo ID
  getById: async (id) => {
    const response = await api.get(`/profiles/${id}`);
    return response.data;
  },

  // Tạo profile mới
  create: async (profileData) => {
    const response = await api.post('/profiles', profileData);
    return response.data;
  },

  // Cập nhật profile
  update: async (id, profileData) => {
    const response = await api.put(`/profiles/${id}`, profileData);
    return response.data;
  },

  // Xóa profile
  delete: async (id) => {
    const response = await api.delete(`/profiles/${id}`);
    return response.data;
  },
};

export default profileService;